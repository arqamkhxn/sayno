/// Reasons why the application or screen may be blocked by SayNO.
enum BlockReason {
  /// Blocked because restricted content (keywords) was detected.
  restrictedContent,

  /// Blocked because the daily limit configured for the app has been reached.
  dailyLimitReached,
}

/// Extensions providing user-facing text details for block reasons.
extension BlockReasonExtensions on BlockReason {
  /// The premium, calm title to display in the block overlay.
  String get title => switch (this) {
        BlockReason.restrictedContent => 'Access Blocked',
        BlockReason.dailyLimitReached => 'Limit Reached',
      };

  /// The clear, non-aggressive message explaining the block.
  String get message => switch (this) {
        BlockReason.restrictedContent =>
          'This content conflicts with your commitment.',
        BlockReason.dailyLimitReached =>
          'You have reached your daily limit for this application.',
      };
}
