import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/usecases/execute_exit_strategy_use_case.dart';

final exitHandlerProvider = Provider<ExitHandler>((ref) {
  return ExitHandler(ExecuteExitStrategyUseCase());
});

class ExitHandler {
  final ExecuteExitStrategyUseCase _useCase;

  ExitHandler(this._useCase);

  Future<ExitRoute> determineExitRoute({
    required bool hasReflected, 
    required int sessionDuration
  }) async {
    return await _useCase.execute(
      hasReflected: hasReflected,
      sessionDuration: sessionDuration,
    );
  }
}
