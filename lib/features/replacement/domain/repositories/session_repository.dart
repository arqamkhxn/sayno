import '../entities/replacement_session.dart';
import '../entities/reflection.dart';

abstract class SessionRepository {
  Future<void> saveSession(ReplacementSession session);
  Future<ReplacementSession?> getSession(String id);
  Future<void> saveReflection(Reflection reflection);
  
  /// Get the total accumulated usage in seconds for the given date (e.g. YYYY-MM-DD)
  Future<int> getDailyUsageSeconds(String dateString);
  
  /// Update the accumulated usage for the current day
  Future<void> updateDailyUsageSeconds(String dateString, int secondsToAdd);
}
