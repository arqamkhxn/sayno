import 'package:sqflite/sqflite.dart';
import 'session_database.dart';

/// Repository that acts as an abstraction layer between the app_limits database table and controllers.
class LimitRepository {
  LimitRepository({required SessionDatabase database}) : _database = database;

  final SessionDatabase _database;

  /// Saves or updates a daily limit for an application.
  Future<void> saveLimit(String packageName, int limitMinutes) async {
    final db = await _database.database;
    await db.insert(
      'app_limits',
      {
        'package_name': packageName,
        'limit_minutes': limitMinutes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a daily limit for an application.
  Future<void> deleteLimit(String packageName) async {
    final db = await _database.database;
    await db.delete(
      'app_limits',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Retrieves all configured limits from the database.
  Future<Map<String, int>> getLimits() async {
    final db = await _database.database;
    final result = await db.query('app_limits');
    
    final Map<String, int> limits = {};
    for (final row in result) {
      final packageName = row['package_name'] as String;
      final limitMinutes = row['limit_minutes'] as int;
      limits[packageName] = limitMinutes;
    }
    return limits;
  }
}
