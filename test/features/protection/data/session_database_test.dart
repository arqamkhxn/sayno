import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/session_controller.dart';
import 'package:sayno/features/protection/data/session_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for local SQLite tests on host machine
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SessionDatabase Tests', () {
    late SessionDatabase sessionDb;

    setUp(() async {
      // Open in-memory SQLite database (new isolated instance per test)
      final db = await openDatabase(inMemoryDatabasePath, singleInstance: false);
      
      // Manually create schema in the test database
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_name TEXT NOT NULL,
          app_name TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL
        )
      ''');

      sessionDb = SessionDatabase(db: db);
    });

    test('Insert and aggregate today total usage seconds via SQL SUM', () async {
      final now = DateTime.now();
      
      // Override getSystemTime for clock testing
      final originalGetSystemTime = getSystemTime;
      getSystemTime = () => now;

      // Insert some sessions for today
      await sessionDb.insertSession({
        'package_name': 'com.google.android.youtube',
        'app_name': 'YouTube',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(seconds: 120)).toIso8601String(),
        'duration_seconds': 120,
      });

      await sessionDb.insertSession({
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(seconds: 45)).toIso8601String(),
        'duration_seconds': 45,
      });

      // Insert a session for yesterday (should be filtered out)
      final yesterday = now.subtract(const Duration(days: 1));
      await sessionDb.insertSession({
        'package_name': 'com.android.chrome',
        'app_name': 'Chrome',
        'start_time': yesterday.toIso8601String(),
        'end_time': yesterday.add(const Duration(seconds: 300)).toIso8601String(),
        'duration_seconds': 300,
      });

      final totalSeconds = await sessionDb.getTodayTotalUsageSeconds();
      expect(totalSeconds, 165); // 120 + 45

      // Restore system clock
      getSystemTime = originalGetSystemTime;
    });

    test('Insert and aggregate today per app usage seconds via SQL GROUP BY', () async {
      final now = DateTime.now();
      
      final originalGetSystemTime = getSystemTime;
      getSystemTime = () => now;

      await sessionDb.insertSession({
        'package_name': 'com.google.android.youtube',
        'app_name': 'YouTube',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(seconds: 120)).toIso8601String(),
        'duration_seconds': 120,
      });

      await sessionDb.insertSession({
        'package_name': 'com.google.android.youtube',
        'app_name': 'YouTube',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(seconds: 80)).toIso8601String(),
        'duration_seconds': 80,
      });

      await sessionDb.insertSession({
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(seconds: 45)).toIso8601String(),
        'duration_seconds': 45,
      });

      final perAppUsage = await sessionDb.getTodayPerAppUsageSeconds();
      expect(perAppUsage['com.google.android.youtube'], 200); // 120 + 80
      expect(perAppUsage['com.instagram.android'], 45);
      expect(perAppUsage['com.android.chrome'], isNull);

      getSystemTime = originalGetSystemTime;
    });
  });
}
