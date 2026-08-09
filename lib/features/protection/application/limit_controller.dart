import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/limit_repository.dart';
import 'app_detection_controller.dart';
import 'protection_controller.dart';
import 'session_controller.dart';

/// Provider for the LimitRepository.
final limitRepositoryProvider = Provider<LimitRepository>((ref) {
  final db = ref.watch(sessionDatabaseProvider);
  return LimitRepository(database: db);
});

/// Async Notifier Provider for managing app limits.
final appLimitsProvider = AsyncNotifierProvider<AppLimitsNotifier, Map<String, Duration>>(
  AppLimitsNotifier.new,
);

class AppLimitsNotifier extends AsyncNotifier<Map<String, Duration>> {
  late final LimitRepository _repository;

  @override
  Future<Map<String, Duration>> build() async {
    _repository = ref.watch(limitRepositoryProvider);
    final rawLimits = await _repository.getLimits();
    return rawLimits.map((packageName, minutes) => MapEntry(packageName, Duration(minutes: minutes)));
  }

  /// Sets or updates a daily limit for an application.
  Future<void> setLimit(String packageName, Duration limit) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.saveLimit(packageName, limit.inMinutes);
      final platformService = ref.read(protectionPlatformServiceProvider);
      await platformService.setAppLimit(packageName, limit.inSeconds, 'time_limit');
      final current = state.value ?? {};
      final updated = Map<String, Duration>.from(current)..[packageName] = limit;
      return updated;
    });
  }

  /// Removes the daily limit for an application.
  Future<void> removeLimit(String packageName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteLimit(packageName);
      final platformService = ref.read(protectionPlatformServiceProvider);
      await platformService.removeAppLimit(packageName);
      final current = state.value ?? {};
      final updated = Map<String, Duration>.from(current)..remove(packageName);
      return updated;
    });
  }
}

/// Provider evaluating daily limit reach status in real-time.
/// Emits a map of package names to a boolean indicating whether the limit has been reached/exceeded.
final isLimitReachedMapProvider = Provider<Map<String, bool>>((ref) {
  final usage = ref.watch(todayAppUsageProvider);
  final limits = ref.watch(appLimitsProvider).value ?? const {};

  final Map<String, bool> result = {};
  for (final entry in usage.entries) {
    final package = entry.key;
    final appUsage = entry.value;
    final appLimit = limits[package];
    
    if (appLimit != null) {
      // Limit is reached if usage is equal to or greater than the limit duration
      result[package] = appUsage.inSeconds >= appLimit.inSeconds;
    } else {
      // Treat as unlimited if there is no configured limit
      result[package] = false;
    }
  }
  return result;
});

/// Provider indicating whether the currently active monitored app has reached its daily limit.
final isActiveAppLimitReachedProvider = Provider<bool>((ref) {
  final activePackage = ref.watch(activePackageProvider);
  if (activePackage == null) return false;
  
  final limitReachedMap = ref.watch(isLimitReachedMapProvider);
  return limitReachedMap[activePackage] ?? false;
});
