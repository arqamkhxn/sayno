import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/block_overlay_controller.dart';
import 'package:sayno/features/protection/application/protection_controller.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';
import 'package:sayno/features/protection/domain/block_reason.dart';

class StubProtectionPlatformService implements ProtectionPlatformService {
  @override
  Future<List<Map<String, String>>> getInstalledApps() async => [];

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
  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {}
  @override
  Future<bool> performBack() async => true;
  @override
  Future<bool> performHome() async => true;
  @override
  Future<bool> triggerRescan() async => true;
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

void main() {
  group('BlockOverlayController Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          protectionPlatformServiceProvider.overrideWithValue(StubProtectionPlatformService()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is hidden with no block reason', () {
      final state = container.read(blockOverlayProvider);
      expect(state.isVisible, isFalse);
      expect(state.reason, isNull);

      expect(container.read(isBlockOverlayVisibleProvider), isFalse);
      expect(container.read(blockReasonProvider), isNull);
    });

    test('showOverlay updates state with isVisible = true and the correct reason', () {
      // Trigger restrictedContent overlay
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.restrictedContent);

      var state = container.read(blockOverlayProvider);
      expect(state.isVisible, isTrue);
      expect(state.reason, BlockReason.restrictedContent);

      expect(container.read(isBlockOverlayVisibleProvider), isTrue);
      expect(container.read(blockReasonProvider), BlockReason.restrictedContent);

      // Trigger dailyLimitReached overlay
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);

      state = container.read(blockOverlayProvider);
      expect(state.isVisible, isTrue);
      expect(state.reason, BlockReason.dailyLimitReached);

      expect(container.read(isBlockOverlayVisibleProvider), isTrue);
      expect(container.read(blockReasonProvider), BlockReason.dailyLimitReached);
    });

    test('hideOverlay resets state back to hidden', () {
      // Show overlay first
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.restrictedContent);
      expect(container.read(isBlockOverlayVisibleProvider), isTrue);

      // Hide overlay
      container.read(blockOverlayProvider.notifier).hideOverlay();

      final state = container.read(blockOverlayProvider);
      expect(state.isVisible, isFalse);
      expect(state.reason, isNull);

      expect(container.read(isBlockOverlayVisibleProvider), isFalse);
      expect(container.read(blockReasonProvider), isNull);
    });

    test('handleGoBack dismisses the overlay', () {
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.restrictedContent);
      expect(container.read(isBlockOverlayVisibleProvider), isTrue);

      container.read(blockOverlayProvider.notifier).handleGoBack();
      expect(container.read(isBlockOverlayVisibleProvider), isFalse);
    });

    test('handleClose dismisses the overlay', () {
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);
      expect(container.read(isBlockOverlayVisibleProvider), isTrue);

      container.read(blockOverlayProvider.notifier).handleClose();
      expect(container.read(isBlockOverlayVisibleProvider), isFalse);
    });
  });
}
