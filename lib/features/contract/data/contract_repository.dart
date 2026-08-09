import '../domain/contract.dart';
import '../domain/contract_app.dart';
import '../domain/contract_day_record.dart';

abstract class ContractRepository {
  /// Fetches the currently active contract, if any, along with its contract apps.
  Future<Contract?> getActiveContract();

  /// Creates a new contract and associated contract apps in a database transaction.
  Future<int> createContract(Contract contract, List<ContractApp> apps);

  /// Updates the streak counts for an active contract.
  Future<void> updateContractStreak(int contractId, int currentStreak, int longestStreak);

  /// Updates the remaining credits for a specific app under a contract.
  Future<void> updateRemainingCredits(int contractId, String packageName, Duration remaining);

  /// Inserts or updates a calendar day completion record.
  Future<void> recordContractDay(int contractId, String dateUtc, ContractDayStatus status, {bool creditsDeducted = false});

  /// Retrieves all calendar day records for a specific contract.
  Future<List<ContractDayRecord>> getContractDays(int contractId);

  /// Marks a contract as completed/closed.
  Future<void> updateContractStatus(int contractId, ContractStatus status, DateTime completedAtUtc);

  /// Gets the count of all ended contracts (completed or failed).
  Future<int> getCompletedContractsCount();

  /// Retrieves the usage for a specific package on a specific UTC day string ('YYYY-MM-DD').
  Future<Duration> getUsageForPackageOnDateUtc(String packageName, String dateUtc);

  /// Overwrites or restores a contract, its apps, and checklist days from remote sync.
  Future<void> rehydrateContract(Contract contract, List<ContractDayRecord> days);
}
