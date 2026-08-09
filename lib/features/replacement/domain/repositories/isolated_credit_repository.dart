abstract class IsolatedCreditRepository {
  Future<int> getBalance();
  Future<void> addCredits(int amount);
}
