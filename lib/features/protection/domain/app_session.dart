/// Domain model representing a monitored app session.
class AppSession {
  final String packageName;
  final String appName;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;

  const AppSession({
    required this.packageName,
    required this.appName,
    required this.startTime,
    required this.duration,
    this.endTime,
  });

  /// Indicates whether the session is currently active (ongoing).
  bool get isActive => endTime == null;

  AppSession copyWith({
    String? packageName,
    String? appName,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
  }) {
    return AppSession(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }
}
