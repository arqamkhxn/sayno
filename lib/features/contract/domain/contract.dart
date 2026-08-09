import 'contract_app.dart';

enum ContractStatus {
  active,
  completed,
  failed
}

class Contract {
  final int? id;
  final int durationDays;
  final DateTime startTimestampUtc;
  final DateTime endTimestampUtc;
  final DateTime? completedAtUtc;
  final int longestStreak;
  final int currentStreak;
  final ContractStatus status;
  final List<ContractApp> apps;
  final DateTime? updatedAtUtc;

  const Contract({
    this.id,
    required this.durationDays,
    required this.startTimestampUtc,
    required this.endTimestampUtc,
    this.completedAtUtc,
    this.longestStreak = 0,
    this.currentStreak = 0,
    required this.status,
    this.apps = const [],
    this.updatedAtUtc,
  });

  bool get isActive => status == ContractStatus.active;
  bool get isCompleted => status == ContractStatus.completed;
  bool get isFailed => status == ContractStatus.failed;

  /// Evaluates whether the contract has reached its duration end relative to a UTC time.
  bool isExpired(DateTime currentUtc) => currentUtc.isAfter(endTimestampUtc);

  /// Calculates the current day number of the contract (1-indexed).
  int currentDayNumber(DateTime currentUtc) {
    if (currentUtc.isBefore(startTimestampUtc)) return 1;
    final difference = currentUtc.difference(startTimestampUtc).inDays;
    return (difference + 1).clamp(1, durationDays);
  }

  Contract copyWith({
    int? id,
    int? durationDays,
    DateTime? startTimestampUtc,
    DateTime? endTimestampUtc,
    DateTime? completedAtUtc,
    int? longestStreak,
    int? currentStreak,
    ContractStatus? status,
    List<ContractApp>? apps,
    DateTime? updatedAtUtc,
  }) {
    return Contract(
      id: id ?? this.id,
      durationDays: durationDays ?? this.durationDays,
      startTimestampUtc: startTimestampUtc ?? this.startTimestampUtc,
      endTimestampUtc: endTimestampUtc ?? this.endTimestampUtc,
      completedAtUtc: completedAtUtc ?? this.completedAtUtc,
      longestStreak: longestStreak ?? this.longestStreak,
      currentStreak: currentStreak ?? this.currentStreak,
      status: status ?? this.status,
      apps: apps ?? this.apps,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}
