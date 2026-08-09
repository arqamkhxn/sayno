import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/isolated_credit_repository.dart';
import '../data/repositories/isolated_credit_repository_impl.dart';
import '../../../core/providers/shared_prefs_provider.dart';

final isolatedCreditRepositoryProvider = Provider<IsolatedCreditRepository>((ref) {
  return IsolatedCreditRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

final isolatedCreditControllerProvider = StateNotifierProvider<IsolatedCreditController, int>((ref) {
  final repo = ref.watch(isolatedCreditRepositoryProvider);
  final controller = IsolatedCreditController(repo);
  controller.loadBalance();
  return controller;
});

class IsolatedCreditController extends StateNotifier<int> {
  final IsolatedCreditRepository _repository;

  IsolatedCreditController(this._repository) : super(0);

  Future<void> loadBalance() async {
    state = await _repository.getBalance();
  }

  Future<void> rewardReflection() async {
    // Arbitrary fake credit reward for reflection
    await _repository.addCredits(10);
    await loadBalance();
  }
}
