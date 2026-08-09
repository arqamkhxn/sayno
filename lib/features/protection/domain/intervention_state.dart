import 'block_reason.dart';

/// Represents the runtime state of the intervention engine.
class InterventionState {
  /// Whether an active intervention flow is currently in progress.
  final bool inProgress;

  /// The active reason triggering the intervention, if any.
  final BlockReason? reason;

  /// The count of BACK attempts performed during the restricted content flow.
  final int attemptCount;

  const InterventionState({
    required this.inProgress,
    this.reason,
    required this.attemptCount,
  });

  /// The initial clean state when no intervention is running.
  const InterventionState.initial()
      : inProgress = false,
        reason = null,
        attemptCount = 0;

  InterventionState copyWith({
    bool? inProgress,
    BlockReason? reason,
    int? attemptCount,
  }) {
    return InterventionState(
      inProgress: inProgress ?? this.inProgress,
      reason: reason ?? this.reason,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterventionState &&
          runtimeType == other.runtimeType &&
          inProgress == other.inProgress &&
          reason == other.reason &&
          attemptCount == other.attemptCount;

  @override
  int get hashCode =>
      inProgress.hashCode ^ reason.hashCode ^ attemptCount.hashCode;

  @override
  String toString() {
    return 'InterventionState('
        'inProgress: $inProgress, '
        'reason: $reason, '
        'attemptCount: $attemptCount'
        ')';
  }
}
