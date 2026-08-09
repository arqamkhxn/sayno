import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/isolated_credit_repository.dart';

class IsolatedCreditRepositoryImpl implements IsolatedCreditRepository {
  final SharedPreferences _prefs;
  static const String _balanceKey = 'replacement_isolated_credits';

  IsolatedCreditRepositoryImpl(this._prefs);

  @override
  Future<int> getBalance() async {
    return _prefs.getInt(_balanceKey) ?? 0;
  }

  @override
  Future<void> addCredits(int amount) async {
    final current = await getBalance();
    await _prefs.setInt(_balanceKey, current + amount);
  }
}
