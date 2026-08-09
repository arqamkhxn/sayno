import '../repositories/session_repository.dart';
import '../policies/replacement_session_policy.dart';

class TickSessionTimerUseCase {
  final SessionRepository _sessionRepository;
  final ReplacementSessionPolicy _policy;

  TickSessionTimerUseCase(this._sessionRepository, this._policy);

  /// Ticks the timer by [secondsElapsed].
  /// Returns false if the daily allowance is reached and the session must stop.
  Future<bool> execute(String dateString, int secondsElapsed) async {
    await _sessionRepository.updateDailyUsageSeconds(dateString, secondsElapsed);
    
    final totalDaily = await _sessionRepository.getDailyUsageSeconds(dateString);
    return _policy.canContinueSession(totalDaily);
  }
}
