import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/block_reason.dart';
import 'protection_controller.dart';

/// The runtime, ephemeral state for the block overlay.
class BlockOverlayState {
  /// Whether the block overlay should be currently visible on the screen.
  final bool isVisible;

  /// The active reason for blocking, or null if overlay is hidden.
  final BlockReason? reason;

  const BlockOverlayState({
    required this.isVisible,
    this.reason,
  });

  /// The initial state when no block overlay is visible.
  const BlockOverlayState.initial()
      : isVisible = false,
        reason = null;

  BlockOverlayState copyWith({
    bool? isVisible,
    BlockReason? reason,
  }) {
    return BlockOverlayState(
      isVisible: isVisible ?? this.isVisible,
      reason: reason ?? this.reason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockOverlayState &&
          runtimeType == other.runtimeType &&
          isVisible == other.isVisible &&
          reason == other.reason;

  @override
  int get hashCode => isVisible.hashCode ^ reason.hashCode;
}

/// Riverpod provider managing the state of the Block Overlay.
final blockOverlayProvider =
    NotifierProvider<BlockOverlayNotifier, BlockOverlayState>(
  BlockOverlayNotifier.new,
);

class BlockOverlayNotifier extends Notifier<BlockOverlayState> {
  @override
  BlockOverlayState build() => const BlockOverlayState.initial();

  /// Displays the block overlay with a specific reason.
  void showOverlay(BlockReason reason) {
    state = BlockOverlayState(
      isVisible: true,
      reason: reason,
    );
  }

  /// Dismisses the block overlay.
  void hideOverlay() {
    state = const BlockOverlayState.initial();
  }

  /// Action callback when the user taps "Go Back" on the block overlay.
  /// Dismisses the overlay first, then triggers native back action.
  void handleGoBack() {
    hideOverlay();
    ref.read(protectionPlatformServiceProvider).performBack();
  }

  /// Action callback when the user taps "Close" on the block overlay.
  /// Dismisses the overlay first, then triggers native home action.
  void handleClose() {
    hideOverlay();
    ref.read(protectionPlatformServiceProvider).performHome();
  }
}

// ---------------------------------------------------------------------------
// Convenience selector providers
// ---------------------------------------------------------------------------

/// Provider emitting whether the block overlay is currently visible.
final isBlockOverlayVisibleProvider = Provider<bool>((ref) {
  return ref.watch(blockOverlayProvider).isVisible;
});

/// Provider emitting the current active block reason (or null if hidden).
final blockReasonProvider = Provider<BlockReason?>((ref) {
  return ref.watch(blockOverlayProvider).reason;
});
