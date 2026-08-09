import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/block_reason.dart';
import '../domain/intervention_state.dart';
import '../domain/keyword_scan_state.dart';
import 'app_detection_controller.dart';
import 'block_overlay_controller.dart';
import 'keyword_controller.dart';
import 'limit_controller.dart';
import 'protection_controller.dart';

const int kMaxBackAttempts = 2;
const Duration kInterventionWaitDuration = Duration(milliseconds: 250);
const Duration kRescanTimeoutDuration = Duration(milliseconds: 1500);

final interventionStateProvider =
    NotifierProvider<InterventionNotifier, InterventionState>(
  InterventionNotifier.new,
);

class InterventionNotifier extends Notifier<InterventionState> {
  @override
  InterventionState build() {
    // Listen for restricted content detection changes
    ref.listen<bool>(restrictedContentDetectedProvider, (previous, next) {
      if (next && !(previous ?? false)) {
        _triggerRestrictedContentIntervention();
      }
    });

    // Listen for daily limit reached changes
    ref.listen<bool>(isActiveAppLimitReachedProvider, (previous, next) {
      if (next && !(previous ?? false)) {
        _triggerLimitReachedIntervention();
      }
    });

    // Listen for active package changes
    ref.listen<String?>(activePackageProvider, (previous, next) {
      if (next != previous && !state.inProgress) {
        // Reset state only when foreground package changes AND no intervention is active
        state = const InterventionState.initial();
      }
    });

    return const InterventionState.initial();
  }

  Future<void> _triggerRestrictedContentIntervention() async {
    // Safety check: Only one intervention may run at a time, and not if overlay is already visible
    if (state.inProgress || ref.read(isBlockOverlayVisibleProvider)) {
      return;
    }

    state = const InterventionState(
      inProgress: true,
      reason: BlockReason.restrictedContent,
      attemptCount: 0,
    );

    final platformService = ref.read(protectionPlatformServiceProvider);
    final blockOverlayNotifier = ref.read(blockOverlayProvider.notifier);

    for (int attempt = 1; attempt <= kMaxBackAttempts; attempt++) {
      // 1. Perform BACK action
      final backSuccess = await platformService.performBack();
      if (!backSuccess) {
        // Fallback: HOME -> Overlay
        await platformService.performHome();
        blockOverlayNotifier.showOverlay(BlockReason.restrictedContent);
        state = state.copyWith(inProgress: false);
        return;
      }

      state = state.copyWith(attemptCount: attempt);

      // 2. Wait
      await Future.delayed(kInterventionWaitDuration);

      // 3. Trigger rescan and wait for result
      try {
        final scanResult = await _triggerRescanAndWait();
        if (!scanResult.restrictedContentDetected) {
          // No longer restricted, stop intervention flow
          state = state.copyWith(inProgress: false);
          return;
        }
      } catch (e) {
        // Timeout or error: proceed with next attempt
      }
    }

    // Still restricted after max BACK attempts: show block overlay
    blockOverlayNotifier.showOverlay(BlockReason.restrictedContent);
    state = state.copyWith(inProgress: false);
  }

  void _triggerLimitReachedIntervention() {
    // Safety check: Only one intervention may run at a time, and not if overlay is already visible
    if (state.inProgress || ref.read(isBlockOverlayVisibleProvider)) {
      return;
    }

    state = const InterventionState(
      inProgress: true,
      reason: BlockReason.dailyLimitReached,
      attemptCount: 0,
    );

    // Show block overlay directly (no BACK required)
    ref.read(blockOverlayProvider.notifier).showOverlay(BlockReason.dailyLimitReached);
    state = state.copyWith(inProgress: false);
  }

  Future<KeywordScanState> _triggerRescanAndWait() async {
    final platformService = ref.read(protectionPlatformServiceProvider);
    final completer = Completer<KeywordScanState>();
    Timer? timeoutTimer;
    ProviderSubscription<KeywordScanState>? subscription;

    subscription = ref.listen<KeywordScanState>(
      keywordScanProvider,
      (previous, next) {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          subscription?.close();
          completer.complete(next);
        }
      },
      fireImmediately: false,
    );

    final triggerSuccess = await platformService.triggerRescan();
    if (!triggerSuccess) {
      subscription.close();
      return KeywordScanState.initial();
    }

    timeoutTimer = Timer(kRescanTimeoutDuration, () {
      if (!completer.isCompleted) {
        subscription?.close();
        completer.completeError(
          TimeoutException('Timed out waiting for rescan result'),
        );
      }
    });

    return completer.future;
  }
}

// Selector providers
final interventionInProgressProvider = Provider<bool>((ref) {
  return ref.watch(interventionStateProvider).inProgress;
});

final interventionReasonProvider = Provider<BlockReason?>((ref) {
  return ref.watch(interventionStateProvider).reason;
});

final interventionAttemptCountProvider = Provider<int>((ref) {
  return ref.watch(interventionStateProvider).attemptCount;
});
