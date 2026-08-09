import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../domain/monitored_apps.dart';
import 'keyword_controller.dart';
import 'protection_controller.dart';
import 'notification_service.dart';

/// Provider for the screen state (true if screen is on, false if screen is off).
/// Defaults to false (safe/pessimistic startup) until initialized from Android.
final isScreenOnProvider = StateProvider<bool>((ref) => false);

/// Provider for the device lock state (true if device is unlocked, false if locked).
/// Defaults to false (safe/pessimistic startup) until initialized from Android.
final isDeviceUnlockedProvider = StateProvider<bool>((ref) => false);

/// Provider for the accessibility protection service state (true if running/enabled, false if disabled).
/// Defaults to false (safe/pessimistic startup) until initialized from Android.
final isProtectionAvailableProvider = StateProvider<bool>((ref) => false);

/// Provider for the active monitored application package name.
/// Value is null if no monitored app is active.
final activePackageProvider = NotifierProvider<ActivePackageNotifier, String?>(
  ActivePackageNotifier.new,
);

class ActivePackageNotifier extends Notifier<String?> {
  @override
  String? build() {
    final platformService = ref.watch(protectionPlatformServiceProvider);

    // Set up the generic accessibility event listener
    platformService.setAccessibilityEventListener((event) {
      final type = event['type'] as String?;
      switch (type) {
        case 'app_change':
          final packageName = event['packageName'] as String?;
          state = packageName;

          // Reset keyword scan state when leaving a high-risk app
          if (packageName == null ||
              !highRiskPackages.contains(packageName)) {
            ref.read(keywordScanProvider.notifier).resetState();
          }
          break;

        case 'content_scan':
          // Process native-side matching result — raw text is never sent here
          final packageName = event['packageName'] as String? ?? '';
          final detected = event['restrictedContentDetected'] as bool? ?? false;
          final matchedRaw = event['matchedKeywords'];
          final matched = (matchedRaw is List)
              ? matchedRaw.map((e) => e.toString()).toList()
              : <String>[];
          final timestamp =
              event['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

          ref.read(keywordScanProvider.notifier).processScanResult(
                packageName: packageName,
                detected: detected,
                matched: matched,
                timestamp: timestamp,
              );
          break;

        case 'screen_off':
          ref.read(isScreenOnProvider.notifier).state = false;
          break;
        case 'screen_on':
          ref.read(isScreenOnProvider.notifier).state = true;
          final isLocked = event['isLocked'] as bool? ?? true;
          ref.read(isDeviceUnlockedProvider.notifier).state = !isLocked;
          break;
        case 'device_unlocked':
          ref.read(isDeviceUnlockedProvider.notifier).state = true;
          break;
        case 'protection_enabled':
          ref.read(isProtectionAvailableProvider.notifier).state = true;
          ref.read(protectionControllerProvider.notifier).refreshStatus();
          break;
        case 'protection_disabled':
          ref.read(isProtectionAvailableProvider.notifier).state = false;
          ref.read(protectionControllerProvider.notifier).refreshStatus();
          break;
        case 'settings_bypass':
          ref.read(notificationServiceProvider).sendNotificationToPartner(
            title: 'SayNO Protection Alert',
            body: 'User has attempted to bypass SayNO protection!',
          );
          break;
        case 'clock_manipulation':
          ref.read(notificationServiceProvider).sendNotificationToPartner(
            title: 'SayNO Protection Alert',
            body: 'User has attempted to bypass SayNO protection!',
          );
          break;
        case 'limit_reached':
          debugPrint('App limit reached event received from native side');
          break;
      }
    });

    // Initialize actual states from Android on startup
    platformService.isScreenOn().then((screenOn) {
      ref.read(isScreenOnProvider.notifier).state = screenOn;
    });

    platformService.isDeviceLocked().then((locked) {
      ref.read(isDeviceUnlockedProvider.notifier).state = !locked;
    });

    platformService.isAccessibilityEnabled().then((isEnabled) {
      ref.read(isProtectionAvailableProvider.notifier).state = isEnabled;
    });

    // Synchronize the centralized monitored apps registry with the native layer
    platformService.updateMonitoredApps(monitoredAppsRegistry.keys.toList());

    // Push the high-risk scanning whitelist to native
    platformService.updateHighRiskApps(highRiskPackages.toList());

    // Push the keyword list to native for on-device matching
    platformService.updateKeywords(exportedKeywordRegistry);

    return null;
  }
}

/// Provider for the user-friendly name of the currently active monitored app.
final activeAppNameProvider = Provider<String?>((ref) {
  final package = ref.watch(activePackageProvider);
  if (package == null) return null;
  return monitoredAppsRegistry[package] ?? 'Unknown App';
});

/// Provider indicating whether a monitored app is currently active.
final isMonitoredAppActiveProvider = Provider<bool>((ref) {
  final package = ref.watch(activePackageProvider);
  return package != null;
});
