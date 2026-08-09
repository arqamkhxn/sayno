import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final protectionPlatformServiceProvider = Provider<ProtectionPlatformService>(
  (ref) => ProtectionPlatformService(),
);

class ProtectionPlatformService {
  ProtectionPlatformService({
    MethodChannel? methodChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(_channelName);

  static const _channelName = 'sayno/protection';

  final MethodChannel _methodChannel;

  Future<bool> isClockManipulated() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'isClockManipulated',
    );
    return result ?? false;
  }

  Future<bool> isAccessibilityEnabled() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'isAccessibilityEnabled',
    );
    return result ?? false;
  }

  Future<bool> isScreenOn() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'isScreenOn',
    );
    return result ?? false;
  }

  Future<bool> isDeviceLocked() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'isDeviceLocked',
    );
    return result ?? false;
  }

  Future<bool> openAccessibilitySettings() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'openAccessibilitySettings',
    );
    return result ?? false;
  }

  Future<bool> updateMonitoredApps(List<String> packageNames) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'updateMonitoredApps',
      packageNames,
    );
    return result ?? false;
  }

  /// Sends the high-risk package whitelist to the native accessibility service.
  ///
  /// Only apps in this set will trigger the keyword scanning node traversal.
  Future<bool> updateHighRiskApps(List<String> packageNames) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'updateHighRiskApps',
      packageNames,
    );
    return result ?? false;
  }

  /// Pushes the keyword list to the native side for on-device matching.
  ///
  /// After this call, the native layer performs all matching internally and
  /// only sends structured detection results across the bridge (not raw text).
  Future<bool> updateKeywords(List<String> keywords) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'updateKeywords',
      keywords,
    );
    return result ?? false;
  }

  Future<bool> performBack() async {
    final result = await _methodChannel.invokeMethod<bool>('performBack');
    return result ?? false;
  }

  Future<bool> performHome() async {
    final result = await _methodChannel.invokeMethod<bool>('performHome');
    return result ?? false;
  }

  Future<bool> triggerRescan() async {
    final result = await _methodChannel.invokeMethod<bool>('triggerRescan');
    return result ?? false;
  }

  Future<bool> setAppLimit(String packageName, int limitSeconds, String restrictionMode) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'setAppLimit',
      {
        'packageName': packageName,
        'limitSeconds': limitSeconds,
        'restrictionMode': restrictionMode,
      },
    );
    return result ?? false;
  }

  Future<bool> removeAppLimit(String packageName) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'removeAppLimit',
      {
        'packageName': packageName,
      },
    );
    return result ?? false;
  }

  Future<int> getUsage(String packageName) async {
    final result = await _methodChannel.invokeMethod<int>(
      'getUsage',
      {
        'packageName': packageName,
      },
    );
    return result ?? 0;
  }

  Future<int> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async {
    final result = await _methodChannel.invokeMethod<int>(
      'getUsageForPackageOnDateUtc',
      {
        'packageName': packageName,
        'dateUtc': dateUtc,
      },
    );
    return result ?? 0;
  }

  Future<Map<String, int>> getAllUsage() async {
    final result = await _methodChannel.invokeMapMethod<String, int>(
      'getAllUsage',
    );
    return result ?? const {};
  }

  Future<bool> updateVerifiedTime(int epochSeconds) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'updateVerifiedTime',
      {'epochSeconds': epochSeconds},
    );
    return result ?? false;
  }

  Future<bool> updateActiveContractStatus(bool isActive) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'updateActiveContractStatus',
      {'isActive': isActive},
    );
    return result ?? false;
  }

  Future<bool> updateReleaseAuthorization(bool isAuthorized) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'updateReleaseAuthorization',
      {'isAuthorized': isAuthorized},
    );
    return result ?? false;
  }

  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAccessibilityEvent') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        callback(data);
      }
    });
  }
}
