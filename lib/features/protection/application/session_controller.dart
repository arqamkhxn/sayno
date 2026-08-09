import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_database.dart';
import '../data/session_repository.dart';
import '../domain/app_session.dart';
import '../domain/monitored_apps.dart';
import 'app_detection_controller.dart';
import 'protection_controller.dart';

/// Overridable clock provider to enable unit testing session timers.
DateTime Function() getSystemTime = () => DateTime.now();

/// Provider for the SQLite session database.
final sessionDatabaseProvider = Provider<SessionDatabase>((ref) => SessionDatabase());

/// Provider for the SessionRepository.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(sessionDatabaseProvider);
  return SessionRepository(database: db);
});

/// Provider for the currently active monitored app session, if any.
final activeSessionProvider = NotifierProvider<ActiveSessionNotifier, AppSession?>(
  ActiveSessionNotifier.new,
);

class ActiveSessionNotifier extends Notifier<AppSession?> {
  @override
  AppSession? build() {
    final activePackage = ref.watch(activePackageProvider);
    final isScreenOn = ref.watch(isScreenOnProvider);
    final isDeviceUnlocked = ref.watch(isDeviceUnlockedProvider);
    final isProtectionAvailable = ref.watch(isProtectionAvailableProvider);
    
    final repository = ref.read(sessionRepositoryProvider);

    final shouldTrack = activePackage != null &&
        isScreenOn &&
        isDeviceUnlocked &&
        isProtectionAvailable;

    if (!shouldTrack) {
      return null;
    }

    final appName = monitoredAppsRegistry[activePackage] ?? 'Unknown App';
    final startTime = getSystemTime();

    final session = AppSession(
      packageName: activePackage,
      appName: appName,
      startTime: startTime,
      duration: Duration.zero,
    );

    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state;
      if (current != null) {
        state = current.copyWith(
          duration: getSystemTime().difference(current.startTime),
        );
      }
    });

    ref.onDispose(() {
      timer.cancel();

      final endTime = getSystemTime();
      final finalSession = session.copyWith(
        endTime: endTime,
        duration: endTime.difference(session.startTime),
      );

      // Save only if session has a positive duration to avoid cluttering DB
      if (finalSession.duration.inSeconds > 0) {
        // Save asynchronously in the next event loop tick to avoid Riverpod build-phase issues.
        Future.delayed(Duration.zero, () async {
          await repository.saveSession(finalSession);
          ref.invalidate(persistedTodayUsageProvider);
          ref.invalidate(persistedTodayAppUsageProvider);
        });
      }
    });

    return session;
  }
}

/// Provider for the total count of monitored app sessions started in the current run.
final sessionCountProvider = NotifierProvider<SessionCountNotifier, int>(
  SessionCountNotifier.new,
);

class SessionCountNotifier extends Notifier<int> {
  @override
  int build() {
    ref.listen<String?>(activePackageProvider, (previous, next) {
      if (next != null && next != previous) {
        state = state + 1;
      }
    });

    // Check startup state: if an app is already active, start count at 1.
    final initialPackage = ref.read(activePackageProvider);
    return initialPackage != null ? 1 : 0;
  }
}

/// Provider for today's persisted usage (only completed sessions) from the repository.
final persistedTodayUsageProvider = FutureProvider<Duration>((ref) async {
  final platformService = ref.watch(protectionPlatformServiceProvider);
  final usageMap = await platformService.getAllUsage();
  final totalSeconds = usageMap.values.fold<int>(0, (sum, usage) => sum + usage);
  return Duration(seconds: totalSeconds);
});

/// Provider for the current ongoing session's duration.
final activeSessionDurationProvider = Provider<Duration>((ref) {
  final activeSession = ref.watch(activeSessionProvider);
  return activeSession?.duration ?? Duration.zero;
});

/// Provider for today's overall usage (persisted totals + current active session duration).
final todayTotalUsageProvider = Provider<Duration>((ref) {
  final persistedUsage = ref.watch(persistedTodayUsageProvider).value ?? Duration.zero;
  final activeDuration = ref.watch(activeSessionDurationProvider);
  return persistedUsage + activeDuration;
});

/// Provider for today's persisted per-app usage map.
final persistedTodayAppUsageProvider = FutureProvider<Map<String, Duration>>((ref) async {
  final platformService = ref.watch(protectionPlatformServiceProvider);
  final usageMap = await platformService.getAllUsage();
  return usageMap.map((packageName, seconds) => MapEntry(packageName, Duration(seconds: seconds)));
});

/// Provider for today's overall per-app usage (persisted totals + current active session duration).
final todayAppUsageProvider = Provider<Map<String, Duration>>((ref) {
  final persisted = ref.watch(persistedTodayAppUsageProvider).value ?? const {};
  final activeSession = ref.watch(activeSessionProvider);
  if (activeSession == null) {
    return persisted;
  }

  final result = Map<String, Duration>.from(persisted);
  final package = activeSession.packageName;
  result[package] = (result[package] ?? Duration.zero) + activeSession.duration;
  return result;
});
