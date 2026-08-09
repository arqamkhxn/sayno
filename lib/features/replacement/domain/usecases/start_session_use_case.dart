import '../entities/replacement_session.dart';
import '../repositories/session_repository.dart';
import '../policies/replacement_session_policy.dart';


class StartSessionUseCase {
  final SessionRepository _sessionRepository;
  final ReplacementSessionPolicy _policy;

  StartSessionUseCase(this._sessionRepository, this._policy);

  Future<ReplacementSession?> execute(String videoId) async {
    final today = _getTodayDateString();
    final dailyUsage = await _sessionRepository.getDailyUsageSeconds(today);
    
    if (!_policy.canContinueSession(dailyUsage)) {
      return null; // Cannot start session, limit reached
    }

    final session = ReplacementSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      videoId: videoId,
      durationSeconds: 0,
      startedAt: DateTime.now().toUtc(),
    );

    await _sessionRepository.saveSession(session);
    return session;
  }

  String _getTodayDateString() {
    final now = DateTime.now().toUtc();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
