import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../protection/application/protection_controller.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/application/limit_controller.dart';
import '../domain/contract.dart';
import '../domain/contract_app.dart';
import '../domain/contract_day_record.dart';
import '../data/contract_repository.dart';
import '../data/sqlite_contract_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../settings/application/partner_controller.dart';
import '../../protection/data/cloud_sync_service.dart';

/// Provider for the ContractRepository.
final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  final db = ref.watch(sessionDatabaseProvider);
  return SqliteContractRepository(database: db);
});

/// Provider for the count of completed contracts.
final completedContractsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(contractRepositoryProvider);
  return repo.getCompletedContractsCount();
});

/// Async Notifier Provider managing the currently active contract.
final activeContractProvider = AsyncNotifierProvider<ActiveContractNotifier, Contract?>(
  ActiveContractNotifier.new,
);

class ActiveContractNotifier extends AsyncNotifier<Contract?> {
  ContractRepository get _repository => ref.read(contractRepositoryProvider);

  @override
  Future<Contract?> build() async {
    return _repository.getActiveContract();
  }

  /// Creates a new contract and associated contract apps, updating native limits.
  Future<void> createContract(int durationDays, List<ContractApp> apps) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = getSystemTime().toUtc();
      final end = now.add(Duration(days: durationDays));
      final contract = Contract(
        durationDays: durationDays,
        startTimestampUtc: now,
        endTimestampUtc: end,
        status: ContractStatus.active,
      );
      final id = await _repository.createContract(contract, apps);
      final savedContract = contract.copyWith(id: id, apps: apps, updatedAtUtc: now);

      // Push daily limits for contract apps to native protection
      final platformService = ref.read(protectionPlatformServiceProvider);
      for (final app in apps) {
        await platformService.setAppLimit(app.packageName, app.dailyLimit.inSeconds, app.restrictionMode.name);
      }

      // Trigger Cloud Sync
      final isFirebase = ref.read(firebaseInitializedProvider);
      if (isFirebase) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          unawaited(ref.read(cloudSyncServiceProvider).syncContract(user.uid, savedContract));
        }
      }

      ref.invalidate(completedContractsCountProvider);
      return savedContract;
    });
  }

  /// Borrows minutes for a contract app, marking today as failed and updating native limits.
  Future<void> borrowMinutes(String packageName, Duration amount) async {
    final active = state.value;
    if (active == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final appIndex = active.apps.indexWhere((a) => a.packageName == packageName);
      if (appIndex == -1) return active;

      final app = active.apps[appIndex];
      final newRemaining = app.remainingCredits - amount;

      // Update remaining credits in database
      await _repository.updateRemainingCredits(active.id!, packageName, newRemaining);

      // Record Red Day for today (UTC date string)
      final todayUtcStr = getSystemTime().toUtc().toIso8601String().substring(0, 10);
      await _repository.recordContractDay(active.id!, todayUtcStr, ContractDayStatus.red);

      // Reset current streak to 0
      await _repository.updateContractStreak(active.id!, 0, active.longestStreak);

      // Extend native daily limit by current usage + borrowed duration
      final platformService = ref.read(protectionPlatformServiceProvider);
      final currentUsageSec = await platformService.getUsage(packageName);
      final newLimitSec = currentUsageSec + amount.inSeconds;
      await platformService.setAppLimit(packageName, newLimitSec, app.restrictionMode.name);

      // Invalidate calendar to force UI update
      ref.invalidate(contractCalendarProvider(active.id!));

      // Reload contract
      final updated = await _repository.getActiveContract();
      if (updated != null) {
        final isFirebase = ref.read(firebaseInitializedProvider);
        if (isFirebase) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            unawaited(ref.read(cloudSyncServiceProvider).syncContract(user.uid, updated));
          }
        }
      }

      return updated;
    });
  }

  /// Archives/completes the active contract and restores standard Phase 2 app limits.
  Future<void> completeActiveContract(ContractStatus status) async {
    final active = state.value;
    if (active == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = getSystemTime().toUtc();
      await _repository.updateContractStatus(active.id!, status, now);
      final updated = active.copyWith(status: status, completedAtUtc: now, updatedAtUtc: now);

      // Restore generic Phase 2 limits or remove native limits
      final platformService = ref.read(protectionPlatformServiceProvider);
      final phase2Limits = ref.read(appLimitsProvider).value ?? const {};

      for (final app in active.apps) {
        final phase2Limit = phase2Limits[app.packageName];
        if (phase2Limit != null) {
          await platformService.setAppLimit(app.packageName, phase2Limit.inSeconds, 'time_limit');
        } else {
          await platformService.removeAppLimit(app.packageName);
        }
      }

      // Trigger Cloud Sync
      final isFirebase = ref.read(firebaseInitializedProvider);
      if (isFirebase) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          unawaited(ref.read(cloudSyncServiceProvider).syncContract(user.uid, updated));
        }
      }

      ref.invalidate(completedContractsCountProvider);
      return null;
    });
  }
}

/// Provider for calendar day records for a specific contract.
final contractCalendarProvider = FutureProvider.family<List<ContractDayRecord>, int>((ref, contractId) async {
  final repo = ref.watch(contractRepositoryProvider);
  return repo.getContractDays(contractId);
});

/// Provider aggregating real-time usage stats for apps under the active contract.
final contractTodayUsageProvider = Provider<Map<String, Duration>>((ref) {
  final activeContractVal = ref.watch(activeContractProvider).value;
  if (activeContractVal == null) return const {};

  final todayUsage = ref.watch(todayAppUsageProvider);
  final Map<String, Duration> contractUsage = {};
  for (final app in activeContractVal.apps) {
    contractUsage[app.packageName] = todayUsage[app.packageName] ?? Duration.zero;
  }
  return contractUsage;
});

/// Provider for the ContractValidationService.
final contractValidationServiceProvider = Provider<ContractValidationService>((ref) {
  return ContractValidationService(ref);
});

class ContractValidationService {
  final Ref ref;
  ContractValidationService(this.ref);

  /// Performs UTC midnight day transitions and streak calculations.
  Future<void> performValidation() async {
    final activeContract = await ref.read(activeContractProvider.future);
    if (activeContract == null) return;

    final repo = ref.read(contractRepositoryProvider);
    final nowUtc = getSystemTime().toUtc();

    final startDay = activeContract.startTimestampUtc;
    DateTime currentDay = DateTime.utc(startDay.year, startDay.month, startDay.day);
    final yesterday = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day).subtract(const Duration(days: 1));

    int currentStreak = activeContract.currentStreak;
    int longestStreak = activeContract.longestStreak;
    bool streakUpdated = false;

    final existingDays = await repo.getContractDays(activeContract.id!);
    final Map<String, ContractDayRecord> existingDaysMap = {
      for (final d in existingDays) d.dateUtc: d
    };

    final Map<String, Duration> runningCredits = {
      for (final app in activeContract.apps) app.packageName: app.remainingCredits
    };

    while (currentDay.isBefore(yesterday) || currentDay.isAtSameMomentAs(yesterday)) {
      final dateStr = currentDay.toIso8601String().substring(0, 10);
      final existingRecord = existingDaysMap[dateStr];

      if (existingRecord == null) {
        bool isGreen = true;
        for (final app in activeContract.apps) {
          final usageSeconds = await ref.read(protectionPlatformServiceProvider).getUsageForPackageOnDateUtc(app.packageName, dateStr);
          final usage = Duration(seconds: usageSeconds);
          if (usage.inSeconds > app.dailyLimit.inSeconds) {
            isGreen = false;
          }

          final currentCredits = runningCredits[app.packageName] ?? app.remainingCredits;
          final newRemaining = currentCredits - usage;
          runningCredits[app.packageName] = newRemaining;
          await repo.updateRemainingCredits(activeContract.id!, app.packageName, newRemaining);
        }

        final status = isGreen ? ContractDayStatus.green : ContractDayStatus.red;
        await repo.recordContractDay(activeContract.id!, dateStr, status, creditsDeducted: true);

        if (status == ContractDayStatus.green) {
          currentStreak++;
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
        } else {
          currentStreak = 0;
        }
        streakUpdated = true;
      } else if (!existingRecord.creditsDeducted) {
        for (final app in activeContract.apps) {
          final usageSeconds = await ref.read(protectionPlatformServiceProvider).getUsageForPackageOnDateUtc(app.packageName, dateStr);
          final usage = Duration(seconds: usageSeconds);
          final baseUsageSeconds = usage.inSeconds < app.dailyLimit.inSeconds ? usage.inSeconds : app.dailyLimit.inSeconds;

          final currentCredits = runningCredits[app.packageName] ?? app.remainingCredits;
          final newRemaining = currentCredits - Duration(seconds: baseUsageSeconds);
          runningCredits[app.packageName] = newRemaining;
          await repo.updateRemainingCredits(activeContract.id!, app.packageName, newRemaining);
        }

        await repo.recordContractDay(activeContract.id!, dateStr, existingRecord.status, creditsDeducted: true);
        streakUpdated = true;
      }

      currentDay = currentDay.add(const Duration(days: 1));
    }

    if (streakUpdated) {
      await repo.updateContractStreak(activeContract.id!, currentStreak, longestStreak);
      
      // Trigger Cloud Sync
      final updated = await repo.getActiveContract();
      if (updated != null) {
        final isFirebase = ref.read(firebaseInitializedProvider);
        if (isFirebase) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            unawaited(ref.read(cloudSyncServiceProvider).syncContract(user.uid, updated));
          }
        }
      }

      ref.invalidate(activeContractProvider);
      ref.invalidate(contractCalendarProvider(activeContract.id!));
    }
  }
}
