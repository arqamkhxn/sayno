import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/replacement_session.dart';
import '../domain/usecases/start_session_use_case.dart';
import '../domain/usecases/tick_session_timer_use_case.dart';
import 'session_providers.dart';

final sessionControllerProvider = StateNotifierProvider<SessionController, ReplacementSession?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  final policy = ref.watch(replacementSessionPolicyProvider);
  return SessionController(
    StartSessionUseCase(repo, policy),
    TickSessionTimerUseCase(repo, policy),
  );
});

class SessionController extends StateNotifier<ReplacementSession?> {
  final StartSessionUseCase _startUseCase;
  final TickSessionTimerUseCase _tickUseCase;
  Timer? _timer;
  int _sessionDuration = 0;

  SessionController(this._startUseCase, this._tickUseCase) : super(null);

  Future<bool> startSession(String videoId) async {
    final session = await _startUseCase.execute(videoId);
    if (session == null) {
      return false; // Not allowed to start
    }
    state = session;
    _sessionDuration = 0;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _sessionDuration++;
      
      final today = _getTodayDateString();
      final canContinue = await _tickUseCase.execute(today, 1);
      
      if (!canContinue) {
        endSession();
      } else {
        // Update state to trigger UI rebuilds if needed (time remaining)
        state = state?.copyWith(durationSeconds: _sessionDuration);
      }
    });
    return true;
  }

  void endSession() {
    _timer?.cancel();
    if (state != null) {
      state = state?.copyWith(completedAt: DateTime.now().toUtc());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getTodayDateString() {
    final now = DateTime.now().toUtc();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
