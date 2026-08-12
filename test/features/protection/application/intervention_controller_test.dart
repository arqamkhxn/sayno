import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sayno/features/protection/application/app_detection_controller.dart';
import 'package:sayno/features/protection/application/block_overlay_controller.dart';
import 'package:sayno/features/protection/application/intervention_controller.dart';
import 'package:sayno/features/protection/application/keyword_controller.dart';
import 'package:sayno/features/protection/application/limit_controller.dart';
import 'package:sayno/features/protection/application/protection_controller.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';
import 'package:sayno/features/protection/domain/block_reason.dart';

class MockProtectionPlatformService implements ProtectionPlatformService {
  @override
  Future<List<Map<String, String>>> getInstalledApps() async => [];

  bool isAccessibilityEnabledResult = true;
  bool isScreenOnResult = true;
  bool isDeviceLockedResult = false;

  int performBackCount = 0;
  int performHomeCount = 0;
  int triggerRescanCount = 0;

  bool performBackResult = true;
  bool performHomeResult = true;
  bool triggerRescanResult = true;

  void Function()? onTriggerRescan;

  @override
  Future<bool> isClockManipulated() async => false;

  @override
  Future<bool> isAccessibilityEnabled() async => isAccessibilityEnabledResult;

  @override
  Future<bool> isScreenOn() async => isScreenOnResult;

  @override
  Future<bool> isDeviceLocked() async => isDeviceLockedResult;

  @override
  Future<bool> openAccessibilitySettings() async => true;

  @override
  Future<bool> updateMonitoredApps(List<String> packageNames) async => true;

  @override
  Future<bool> updateHighRiskApps(List<String> packageNames) async => true;

  @override
  Future<bool> updateKeywords(List<String> keywords) async => true;

  @override
  void setAccessibilityEventListener(
      void Function(Map<String, dynamic>) callback) {}

  @override
  Future<bool> performBack() async {
    performBackCount++;
    return performBackResult;
  }

  @override
  Future<bool> performHome() async {
    performHomeCount++;
    return performHomeResult;
  }

  @override
  Future<bool> triggerRescan() async {
    triggerRescanCount++;
    if (onTriggerRescan != null) {
      onTriggerRescan!();
    }
    return triggerRescanResult;
  }

  @override
  Future<bool> setAppLimit(String packageName, int limitSeconds, String restrictionMode) async => true;

  @override
  Future<bool> removeAppLimit(String packageName) async => true;

  @override
  Future<int> getUsage(String packageName) async => 0;

  @override
  Future<int> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async => 0;

  @override
  Future<Map<String, int>> getAllUsage() async => const {};

  @override
  Future<bool> updateVerifiedTime(int epochSeconds) async => true;

  @override
  Future<bool> updateActiveContractStatus(bool isActive) async => true;

  @override
  Future<bool> updateReleaseAuthorization(bool isAuthorized) async => true;
}

class TestActivePackageNotifier extends ActivePackageNotifier {
  @override
  String? build() => null;

  void setPackage(String? package) {
    state = package;
  }
}

void main() {
  late MockProtectionPlatformService mockPlatformService;
  late TestActivePackageNotifier testActivePackageNotifier;
  late StateProvider<bool> testRestrictedDetectedProvider;
  late StateProvider<bool> testLimitReachedProvider;

  setUp(() {
    mockPlatformService = MockProtectionPlatformService();
    testActivePackageNotifier = TestActivePackageNotifier();
    testRestrictedDetectedProvider = StateProvider<bool>((ref) => false);
    testLimitReachedProvider = StateProvider<bool>((ref) => false);
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        protectionPlatformServiceProvider.overrideWithValue(mockPlatformService),
        activePackageProvider.overrideWith(() => testActivePackageNotifier),
        restrictedContentDetectedProvider
            .overrideWith((ref) => ref.watch(testRestrictedDetectedProvider)),
        isActiveAppLimitReachedProvider
            .overrideWith((ref) => ref.watch(testLimitReachedProvider)),
      ],
    );
  }

  group('Intervention Controller tests', () {
    test('Initial state is correct', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = container.read(interventionStateProvider);
      expect(state.inProgress, isFalse);
      expect(state.reason, isNull);
      expect(state.attemptCount, 0);

      expect(container.read(interventionInProgressProvider), isFalse);
      expect(container.read(interventionReasonProvider), isNull);
      expect(container.read(interventionAttemptCountProvider), 0);
    });

    test('Restricted Content Intervention - Successful backout on first attempt', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        // Warm up and listen to providers
        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        mockPlatformService.onTriggerRescan = () {
          // Mock successful backout: keyword scan result becomes clean
          container.read(keywordScanProvider.notifier).processScanResult(
                packageName: 'com.android.chrome',
                detected: false,
                matched: [],
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
          // Set provider value to false as well
          container.read(testRestrictedDetectedProvider.notifier).state = false;
        };

        // Trigger restricted content
        container.read(testRestrictedDetectedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // The notifier is running the intervention flow
        expect(container.read(interventionInProgressProvider), isTrue);
        expect(container.read(interventionReasonProvider), BlockReason.restrictedContent);
        expect(mockPlatformService.performBackCount, 1);
        expect(container.read(interventionAttemptCountProvider), 1);

        // Advance past delay (750ms)
        async.elapse(kInterventionWaitDuration + const Duration(milliseconds: 10));

        // Rescan has been triggered and returned clean content
        expect(mockPlatformService.triggerRescanCount, 1);
        expect(container.read(interventionInProgressProvider), isFalse);
        expect(container.read(isBlockOverlayVisibleProvider), isFalse);
      });
    });

    test('Restricted Content Intervention - Block overlay displayed after max attempts', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        mockPlatformService.onTriggerRescan = () {
          // Mock content still restricted on rescan
          container.read(keywordScanProvider.notifier).processScanResult(
                packageName: 'com.android.chrome',
                detected: true,
                matched: ['porn'],
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
        };

        // Trigger restricted content
        container.read(testRestrictedDetectedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // Attempt 1 BACK
        expect(mockPlatformService.performBackCount, 1);
        expect(container.read(interventionAttemptCountProvider), 1);

        // Wait 750ms
        async.elapse(kInterventionWaitDuration + const Duration(milliseconds: 10));
        expect(mockPlatformService.triggerRescanCount, 1);

        // Attempt 2 BACK
        expect(mockPlatformService.performBackCount, 2);
        expect(container.read(interventionAttemptCountProvider), 2);

        // Wait 750ms
        async.elapse(kInterventionWaitDuration + const Duration(milliseconds: 10));
        expect(mockPlatformService.triggerRescanCount, 2);

        // Finished both attempts and still restricted -> Show Overlay
        expect(container.read(isBlockOverlayVisibleProvider), isTrue);
        expect(container.read(blockReasonProvider), BlockReason.restrictedContent);
        expect(container.read(interventionInProgressProvider), isFalse);
      });
    });

    test('Restricted Content Intervention - Fallback to HOME if BACK action fails', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        // Mock performBack failure
        mockPlatformService.performBackResult = false;

        // Trigger restricted content
        container.read(testRestrictedDetectedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // Try performBack once, fail, immediately perform HOME and show overlay
        expect(mockPlatformService.performBackCount, 1);
        expect(mockPlatformService.performHomeCount, 1);
        expect(container.read(isBlockOverlayVisibleProvider), isTrue);
        expect(container.read(blockReasonProvider), BlockReason.restrictedContent);
        expect(container.read(interventionInProgressProvider), isFalse);
      });
    });

    test('Daily Limit Intervention - Show Block Overlay immediately', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        // Trigger limit reached
        container.read(testLimitReachedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // Directly shows overlay without any BACK or HOME actions
        expect(mockPlatformService.performBackCount, 0);
        expect(mockPlatformService.performHomeCount, 0);
        expect(container.read(isBlockOverlayVisibleProvider), isTrue);
        expect(container.read(blockReasonProvider), BlockReason.dailyLimitReached);
        expect(container.read(interventionInProgressProvider), isFalse);
      });
    });

    test('Safety Rules - Ignore new triggers if intervention is in progress', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        // Set up infinite rescan wait (or just trigger it)
        container.read(testRestrictedDetectedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // Intervention 1 (restrictedContent) starts
        expect(container.read(interventionInProgressProvider), isTrue);
        expect(container.read(interventionReasonProvider), BlockReason.restrictedContent);
        expect(mockPlatformService.performBackCount, 1);

        // Try to trigger daily limit
        container.read(testLimitReachedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // Reason shouldn't change, no duplicate or nested overlay shown
        expect(container.read(interventionReasonProvider), BlockReason.restrictedContent);
        expect(container.read(isBlockOverlayVisibleProvider), isFalse);
      });
    });

    test('Safety Rules - Ignore triggers if overlay is visible', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        // Show overlay manually via overlay controller
        container.read(blockOverlayProvider.notifier).showOverlay(BlockReason.dailyLimitReached);
        expect(container.read(isBlockOverlayVisibleProvider), isTrue);

        // Trigger restricted content detection
        container.read(testRestrictedDetectedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));

        // No new intervention should start
        expect(container.read(interventionInProgressProvider), isFalse);
        expect(mockPlatformService.performBackCount, 0);
      });
    });

    test('Safety Rules - Reset state on package changes only when NOT in progress', () {
      fakeAsync((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(interventionStateProvider, (prev, next) {});
        container.listen(blockOverlayProvider, (prev, next) {});

        // 1. In progress scenario
        container.read(testRestrictedDetectedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));
        expect(container.read(interventionInProgressProvider), isTrue);

        // Foreground app package changes
        testActivePackageNotifier.setPackage('com.instagram.android');
        async.elapse(const Duration(milliseconds: 10));

        // State should NOT reset because intervention is in progress!
        expect(container.read(interventionInProgressProvider), isTrue);
        expect(container.read(interventionReasonProvider), BlockReason.restrictedContent);

        // 2. Not in progress scenario (after intervention ends)
        mockPlatformService.onTriggerRescan = () {
          container.read(keywordScanProvider.notifier).processScanResult(
                packageName: 'com.android.chrome',
                detected: false,
                matched: [],
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
          container.read(testRestrictedDetectedProvider.notifier).state = false;
        };

        // Advance delay to let intervention finish
        async.elapse(kInterventionWaitDuration + const Duration(milliseconds: 10));
        expect(container.read(interventionInProgressProvider), isFalse);

        // Modify state properties manually or trigger a quick limit intervention that completes
        container.read(testLimitReachedProvider.notifier).state = true;
        async.elapse(const Duration(milliseconds: 10));
        // Daily limit intervention completes instantly setting inProgress: false, but the state holds:
        // reason: dailyLimitReached, attemptCount: 0.
        expect(container.read(interventionReasonProvider), BlockReason.dailyLimitReached);

        // Package changes now
        testActivePackageNotifier.setPackage('com.google.android.youtube');
        async.elapse(const Duration(milliseconds: 10));

        // State should reset to initial since inProgress is false
        final state = container.read(interventionStateProvider);
        expect(state.inProgress, isFalse);
        expect(state.reason, isNull);
        expect(state.attemptCount, 0);
      });
    });
  });
}
