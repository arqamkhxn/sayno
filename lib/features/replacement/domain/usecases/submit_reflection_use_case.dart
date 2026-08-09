import '../entities/reflection.dart';
import '../repositories/session_repository.dart';

class SubmitReflectionUseCase {
  final SessionRepository _sessionRepository;

  SubmitReflectionUseCase(this._sessionRepository);

  Future<void> execute(String sessionId, String text) async {
    if (text.trim().isEmpty) return;
    
    final reflection = Reflection(
      sessionId: sessionId,
      text: text.trim(),
      submittedAt: DateTime.now().toUtc(),
    );
    await _sessionRepository.saveReflection(reflection);
  }
}
