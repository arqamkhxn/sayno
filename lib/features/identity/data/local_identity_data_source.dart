import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/identity_configuration.dart';

class LocalIdentityDataSource {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sayno_identity.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE identity_history (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            isActive INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<IdentityConfiguration?> getActiveConfiguration() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'identity_history',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final payload = maps.first['payload'] as String;
    return IdentityConfiguration.fromJson(json.decode(payload));
  }

  Future<void> saveConfiguration(IdentityConfiguration config) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Deactivate previous active configurations
      await txn.update(
        'identity_history',
        {'isActive': 0},
        where: 'isActive = ?',
        whereArgs: [1],
      );

      // Insert new version
      await txn.insert('identity_history', {
        'id': config.id,
        'timestamp': config.timestamp.toIso8601String(),
        'isActive': 1,
        'payload': json.encode(config.toJson()),
      });
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('identity_history');
  }
}
