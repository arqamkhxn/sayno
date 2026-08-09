enum ContractDayStatus {
  green, // Successful Day
  red    // Failed Day (Violation / Borrowing)
}

class ContractDayRecord {
  final int? id;
  final int contractId;
  final String dateUtc; // Format: 'YYYY-MM-DD'
  final ContractDayStatus status;
  final bool creditsDeducted;

  const ContractDayRecord({
    this.id,
    required this.contractId,
    required this.dateUtc,
    required this.status,
    this.creditsDeducted = false,
  });

  ContractDayRecord copyWith({
    int? id,
    int? contractId,
    String? dateUtc,
    ContractDayStatus? status,
    bool? creditsDeducted,
  }) {
    return ContractDayRecord(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      dateUtc: dateUtc ?? this.dateUtc,
      status: status ?? this.status,
      creditsDeducted: creditsDeducted ?? this.creditsDeducted,
    );
  }
}
