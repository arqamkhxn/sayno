abstract class ReplacementSessionPolicy {
  /// The maximum amount of time in seconds the user is allowed to spend
  /// in the Replacement Engine per day.
  int get dailyAllowanceSeconds;

  /// Returns true if the session is allowed to continue based on current usage.
  bool canContinueSession(int dailyUsageSeconds);

  /// Returns the remaining time in seconds for the current day.
  int getRemainingTime(int dailyUsageSeconds);
}

class DefaultReplacementSessionPolicy implements ReplacementSessionPolicy {
  // Version 1 defaults to a hard 30-minute cap (1800 seconds).
  @override
  final int dailyAllowanceSeconds = 1800;

  @override
  bool canContinueSession(int dailyUsageSeconds) {
    return dailyUsageSeconds < dailyAllowanceSeconds;
  }

  @override
  int getRemainingTime(int dailyUsageSeconds) {
    final remaining = dailyAllowanceSeconds - dailyUsageSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
