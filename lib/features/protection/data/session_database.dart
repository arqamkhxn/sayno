import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../application/session_controller.dart';

/// Local SQLite database service for storing and querying completed app sessions.
class SessionDatabase {
  SessionDatabase({Database? db}) : _db = db;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sayno_sessions.db');
    return openDatabase(
      path,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
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
        await db.execute('''
          CREATE TABLE app_limits (
            package_name TEXT PRIMARY KEY,
            limit_minutes INTEGER NOT NULL
          )
        ''');
        await _createContractTables(db);
        await db.execute('''
          CREATE TABLE release_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            requested_at_utc TEXT NOT NULL,
            cooldown_duration_seconds INTEGER NOT NULL,
            status TEXT NOT NULL,
            partner_approved_at_utc TEXT,
            grace_window_expires_at_utc TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE partnerships (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            partner_email TEXT NOT NULL,
            partner_uid TEXT,
            status TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE app_limits (
              package_name TEXT PRIMARY KEY,
              limit_minutes INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await _createContractTables(db);
        }
        if (oldVersion < 4) {
          if (oldVersion >= 3) {
            await db.execute('ALTER TABLE contract_days ADD COLUMN credits_deducted INTEGER DEFAULT 0');
          }
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE release_requests (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              requested_at_utc TEXT NOT NULL,
              cooldown_duration_seconds INTEGER NOT NULL,
              status TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE partnerships (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              partner_email TEXT NOT NULL,
              partner_uid TEXT,
              status TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE contracts ADD COLUMN updated_at_utc TEXT');
          } catch (e) {
            // Already exists or ignore
          }
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE release_requests ADD COLUMN partner_approved_at_utc TEXT');
            await db.execute('ALTER TABLE release_requests ADD COLUMN grace_window_expires_at_utc TEXT');
          } catch (e) {
            // Already exists or ignore
          }
        }
        if (oldVersion < 9) {
          try {
            await db.execute("ALTER TABLE contract_apps ADD COLUMN restriction_mode TEXT DEFAULT 'time_limit'");
          } catch (e) {
            // Already exists or ignore
          }
        }
      },
    );
  }

  Future<void> _createContractTables(Database db) async {
    await db.execute('''
      CREATE TABLE contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        duration_days INTEGER NOT NULL,
        start_timestamp_utc TEXT NOT NULL,
        end_timestamp_utc TEXT NOT NULL,
        completed_at_utc TEXT,
        longest_streak INTEGER DEFAULT 0,
        current_streak INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        updated_at_utc TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE contract_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        daily_limit_seconds INTEGER NOT NULL,
        total_credits_seconds INTEGER NOT NULL,
        remaining_credits_seconds INTEGER NOT NULL,
        restriction_mode TEXT DEFAULT 'time_limit',
        FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE contract_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL,
        date_utc TEXT NOT NULL,
        status TEXT NOT NULL,
        credits_deducted INTEGER DEFAULT 0,
        FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE,
        UNIQUE(contract_id, date_utc)
      )
    ''');
  }

  /// Inserts a completed session row into the database.
  Future<void> insertSession(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('sessions', row);
  }

  /// Calculates today's total usage in seconds using an SQL SUM aggregation.
  Future<int> getTodayTotalUsageSeconds() async {
    final db = await database;
    final now = getSystemTime();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM sessions WHERE start_time >= ? AND start_time <= ?',
      [startOfDay, endOfDay],
    );

    final total = result.first['total'];
    if (total == null) return 0;
    return total as int;
  }

  /// Calculates today's per-app usage in seconds grouped by package name using an SQL SUM aggregation.
  Future<Map<String, int>> getTodayPerAppUsageSeconds() async {
    final db = await database;
    final now = getSystemTime();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

    final result = await db.rawQuery(
      'SELECT package_name, SUM(duration_seconds) as total FROM sessions WHERE start_time >= ? AND start_time <= ? GROUP BY package_name',
      [startOfDay, endOfDay],
    );

    final Map<String, int> usage = {};
    for (final row in result) {
      final packageName = row['package_name'] as String;
      final total = row['total'] as int;
      usage[packageName] = total;
    }
    return usage;
  }
}
