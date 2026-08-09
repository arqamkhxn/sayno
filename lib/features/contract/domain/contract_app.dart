enum RestrictionMode { utility, time_limit, focus, monk }

class ContractApp {
  final int? id;
  final int? contractId;
  final String packageName;
  final Duration dailyLimit;
  final Duration totalCredits;
  final Duration remainingCredits;
  final RestrictionMode restrictionMode;

  const ContractApp({
    this.id,
    this.contractId,
    required this.packageName,
    required this.dailyLimit,
    required this.totalCredits,
    required this.remainingCredits,
    this.restrictionMode = RestrictionMode.time_limit,
  });

  bool get hasCredits => remainingCredits > Duration.zero;

  static RestrictionMode parseMode(String? value) {
    return RestrictionMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RestrictionMode.time_limit,
    );
  }

  ContractApp copyWith({
    int? id,
    int? contractId,
    String? packageName,
    Duration? dailyLimit,
    Duration? totalCredits,
    Duration? remainingCredits,
    RestrictionMode? restrictionMode,
  }) {
    return ContractApp(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      packageName: packageName ?? this.packageName,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      totalCredits: totalCredits ?? this.totalCredits,
      remainingCredits: remainingCredits ?? this.remainingCredits,
      restrictionMode: restrictionMode ?? this.restrictionMode,
    );
  }
}
