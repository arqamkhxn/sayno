import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/app_detection_controller.dart';
import 'package:sayno/features/protection/application/limit_controller.dart';
import 'package:sayno/features/protection/application/protection_controller.dart';
import 'package:sayno/features/protection/application/session_controller.dart';
import 'package:sayno/features/protection/data/limit_repository.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';

class MockLimitRepository implements LimitRepository {
  final Map<String, int> limits = {};

  @override
  Future<void> saveLimit(String packageName, int limitMinutes) async {
    limits[packageName] = limitMinutes;
  }

  @override
  Future<void> deleteLimit(String packageName) async {
    limits.remove(packageName);
  }

  @override
  Future<Map<String, int>> getLimits() async {
    return limits;
  }
}

class StubProtectionPlatformService implements ProtectionPlatformService {
  final List<String> setLimitCalls = [];
  final List<String> removeLimitCalls = [];

  @override
  Future<bool> isClockManipulated() async => false;

  @override
  Future<bool> isAccessibilityEnabled() async => true;

  @override
  Future<bool> isScreenOn() async => true;

  @override
  Future<bool> isDeviceLocked() async => false;

  @override
  Future<bool> openAccessibilitySettings() async => true;

  @override
  Future<bool> updateMonitoredApps(List<String> packageNames) async => true;

  @override
  Future<bool> updateHighRiskApps(List<String> packageNames) async => true;

  @override
  Future<bool> updateKeywords(List<String> keywords) async => true;

  @override
  Future<bool> performBack() async => true;

  @override
  Future<bool> performHome() async => true;

  @override
  Future<bool> triggerRescan() async => true;

  @override
  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {}

  @override
  Future<bool> setAppLimit(String packageName, int limitSeconds, String restrictionMode) async {
    setLimitCalls.add('$packageName:$limitSeconds');
    return true;
  }

  @override
  Future<bool> removeAppLimit(String packageName) async {
    removeLimitCalls.add(packageName);
    return true;
  }

  @override
  Future<bool> updateVerifiedTime(int epochSeconds) async => true;

  @override
  Future<bool> updateActiveContractStatus(bool isActive) async => true;

  @override
  Future<bool> updateReleaseAuthorization(bool isAuthorized) async => true;

  @override
  Future<int> getUsage(String packageName) async => 0;

  @override
  Future<int> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async => 0;

  @override
  Future<Map<String, int>> getAllUsage() async => const {};
}

class TestActivePackageNotifier extends ActivePackageNotifier {
  @override
  String? build() => null;

  void setPackage(String? package) {
    state = package;
  }
}

void main() {
  group('LimitController & Evaluation Tests', () {
    test('Configuring and removing daily limits via appLimitsProvider', () async {
      final mockRepository = MockLimitRepository();
      final stubPlatform = StubProtectionPlatformService();
      
      final container = ProviderContainer(
        overrides: [
          limitRepositoryProvider.overrideWithValue(mockRepository),
          protectionPlatformServiceProvider.overrideWithValue(stubPlatform),
        ],
      );
      addTearDown(container.dispose);

      // Pre-read provider
      expect(await container.read(appLimitsProvider.future), isEmpty);

      // Add a limit
      await container.read(appLimitsProvider.notifier).setLimit(
        'com.instagram.android',
        const Duration(minutes: 20),
      );
      
      var limits = container.read(appLimitsProvider).value;
      expect(limits?['com.instagram.android']?.inMinutes, 20);
      expect(mockRepository.limits['com.instagram.android'], 20);
      expect(stubPlatform.setLimitCalls, ['com.instagram.android:1200']);

      // Remove a limit
      await container.read(appLimitsProvider.notifier).removeLimit('com.instagram.android');
      
      limits = container.read(appLimitsProvider).value;
      expect(limits?['com.instagram.android'], isNull);
      expect(mockRepository.limits['com.instagram.android'], isNull);
      expect(stubPlatform.removeLimitCalls, ['com.instagram.android']);
    });

    test('isLimitReachedMapProvider evaluates limits correctly (Reached / Not Reached / Unlimited)', () async {
      final mockRepository = MockLimitRepository();
      mockRepository.limits['com.instagram.android'] = 20; // 20 mins limit
      mockRepository.limits['com.google.android.youtube'] = 30; // 30 mins limit

      final container = ProviderContainer(
        overrides: [
          limitRepositoryProvider.overrideWithValue(mockRepository),
          protectionPlatformServiceProvider.overrideWithValue(StubProtectionPlatformService()),
          todayAppUsageProvider.overrideWithValue({
            'com.instagram.android': const Duration(minutes: 21), // Reached (21 >= 20)
            'com.google.android.youtube': const Duration(minutes: 15), // Not Reached (15 < 30)
            'com.android.chrome': const Duration(minutes: 40), // Unlimited (No limit configured)
          }),
        ],
      );
      addTearDown(container.dispose);

      // Build limits map (wait for initial load)
      await container.read(appLimitsProvider.future);

      final reachedMap = container.read(isLimitReachedMapProvider);
      expect(reachedMap['com.instagram.android'], isTrue);
      expect(reachedMap['com.google.android.youtube'], isFalse);
      expect(reachedMap['com.android.chrome'], isFalse); // Unlimited app is false
    });

    test('isActiveAppLimitReachedProvider updates in real-time when active app limit is exceeded', () async {
      final mockRepository = MockLimitRepository();
      mockRepository.limits['com.instagram.android'] = 1; // 1 min limit (60s)

      final testPackageNotifier = TestActivePackageNotifier();

      final container = ProviderContainer(
        overrides: [
          limitRepositoryProvider.overrideWithValue(mockRepository),
          protectionPlatformServiceProvider.overrideWithValue(StubProtectionPlatformService()),
          activePackageProvider.overrideWith(() => testPackageNotifier),
          todayAppUsageProvider.overrideWith((ref) {
            // Mock dynamic todayAppUsage: if active session exists, return its duration
            final activeSession = ref.watch(activeSessionProvider);
            return {
              if (activeSession != null)
                activeSession.packageName: activeSession.duration,
            };
          }),
          isScreenOnProvider.overrideWith((ref) => true),
          isDeviceUnlockedProvider.overrideWith((ref) => true),
          isProtectionAvailableProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      // Initialize provider listeners to keep them active
      container.listen(activeSessionProvider, (prev, next) {});
      container.listen(appLimitsProvider, (prev, next) {});
      container.listen(isActiveAppLimitReachedProvider, (prev, next) {});

      // Wait for limits database load
      await container.read(appLimitsProvider.future);

      // Startup state: no app active, limit reached is false
      expect(container.read(isActiveAppLimitReachedProvider), isFalse);

      // Set package to Instagram
      testPackageNotifier.setPackage('com.instagram.android');
      
      // Initially active session exists with 0 seconds usage
      final activeSession = container.read(activeSessionProvider);
      expect(activeSession, isNotNull);
      expect(activeSession!.packageName, 'com.instagram.android');
      expect(container.read(isActiveAppLimitReachedProvider), isFalse);

      // Update session duration to 59 seconds (under 60s limit)
      container.read(activeSessionProvider.notifier).state = activeSession.copyWith(
        duration: const Duration(seconds: 59),
      );
      expect(container.read(isActiveAppLimitReachedProvider), isFalse);

      // Update session duration to 60 seconds (reached limit)
      container.read(activeSessionProvider.notifier).state = activeSession.copyWith(
        duration: const Duration(seconds: 60),
      );
      expect(container.read(isActiveAppLimitReachedProvider), isTrue);

      // Update session duration to 61 seconds (exceeded limit)
      container.read(activeSessionProvider.notifier).state = activeSession.copyWith(
        duration: const Duration(seconds: 61),
      );
      expect(container.read(isActiveAppLimitReachedProvider), isTrue);
    });
  });
}
