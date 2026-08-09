import '../application/session_controller.dart';
import '../domain/app_session.dart';
import 'session_database.dart';

/// Repository that acts as an abstraction layer between the database and the controllers.
class SessionRepository {
  SessionRepository({required SessionDatabase database}) : _database = database;

  final SessionDatabase _database;

  /// Persists a completed session to the database.
  Future<void> saveSession(AppSession session) async {
    await _database.insertSession({
      'package_name': session.packageName,
      'app_name': session.appName,
      'start_time': session.startTime.toIso8601String(),
      'end_time': session.endTime?.toIso8601String() ?? getSystemTime().toIso8601String(),
      'duration_seconds': session.duration.inSeconds,
    });
  }

  /// Retrieves today's total accumulated usage duration from the database.
  Future<Duration> getTodayTotalUsage() async {
    final seconds = await _database.getTodayTotalUsageSeconds();
    return Duration(seconds: seconds);
  }

  /// Retrieves today's accumulated usage duration per-app.
  Future<Map<String, Duration>> getTodayPerAppUsage() async {
    final rawMap = await _database.getTodayPerAppUsageSeconds();
    return rawMap.map((packageName, seconds) => MapEntry(packageName, Duration(seconds: seconds)));
  }
}
