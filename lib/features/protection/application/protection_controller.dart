import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/protection_platform_service.dart';
export '../data/protection_platform_service.dart';
import '../domain/protection_status.dart';
import '../data/cloud_sync_service.dart';
import '../../settings/application/partner_controller.dart';

final protectionControllerProvider =
    AsyncNotifierProvider<ProtectionController, ProtectionStatus>(
  ProtectionController.new,
);

class ProtectionController extends AsyncNotifier<ProtectionStatus> {
  late final ProtectionPlatformService _platformService;

  @override
  Future<ProtectionStatus> build() async {
    _platformService = ref.watch(protectionPlatformServiceProvider);
    return _readProtectionStatus();
  }

  Future<void> refreshStatus() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_readProtectionStatus);
  }

  Future<bool> openAccessibilitySettings() async {
    return _platformService.openAccessibilitySettings();
  }

  Future<ProtectionStatus> _readProtectionStatus() async {
    // Pessimistic Rehydration Check: Restore active contract if storage was cleared
    final isFirebase = ref.read(firebaseInitializedProvider);
    if (isFirebase) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await ref.read(cloudSyncServiceProvider).checkForActiveContractAndRehydrate(user.uid);
        } catch (e) {
          // Fail silently/gracefully on network failures
        }
      }
    }

    try {
      final isEnabled = await _platformService.isAccessibilityEnabled();
      return isEnabled
          ? ProtectionStatus.protected
          : ProtectionStatus.protectionRequired;
    } on PlatformException {
      return ProtectionStatus.unknown;
    } on MissingPluginException {
      return ProtectionStatus.unknown;
    }
  }
}
