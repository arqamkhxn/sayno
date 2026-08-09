import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/replacement_session.dart';
import '../../domain/entities/reflection.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final SharedPreferences _prefs;
  
  static const String _usagePrefix = 'replacement_usage_';
  // Note: For a production app, sessions and reflections would use SQLite.
  // We use SharedPreferences here for the Sprint 7B V1 infrastructure.

  SessionRepositoryImpl(this._prefs);

  @override
  Future<void> saveSession(ReplacementSession session) async {
    // In V1, we only strictly need the daily usage, but we could serialize this to JSON.
  }

  @override
  Future<ReplacementSession?> getSession(String id) async {
    return null;
  }

  @override
  Future<void> saveReflection(Reflection reflection) async {
    // Write-only reflection for V1 as per product blueprint
  }

  @override
  Future<int> getDailyUsageSeconds(String dateString) async {
    return _prefs.getInt('$_usagePrefix$dateString') ?? 0;
  }

  @override
  Future<void> updateDailyUsageSeconds(String dateString, int secondsToAdd) async {
    final current = await getDailyUsageSeconds(dateString);
    await _prefs.setInt('$_usagePrefix$dateString', current + secondsToAdd);
  }
}
