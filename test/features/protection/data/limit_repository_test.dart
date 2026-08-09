import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sayno/features/protection/data/limit_repository.dart';
import 'package:sayno/features/protection/data/session_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for local SQLite tests on host machine
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('LimitRepository Database Tests', () {
    late SessionDatabase sessionDb;
    late LimitRepository limitRepo;

    setUp(() async {
      // Open in-memory SQLite database (new isolated instance per test)
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 2,
        singleInstance: false,
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
        },
      );

      sessionDb = SessionDatabase(db: db);
      limitRepo = LimitRepository(database: sessionDb);
    });

    test('Save limit replaces or inserts successfully', () async {
      // Initially empty
      var limits = await limitRepo.getLimits();
      expect(limits, isEmpty);

      // Save limit
      await limitRepo.saveLimit('com.instagram.android', 30);
      limits = await limitRepo.getLimits();
      expect(limits['com.instagram.android'], 30);

      // Overwrite/update limit
      await limitRepo.saveLimit('com.instagram.android', 45);
      limits = await limitRepo.getLimits();
      expect(limits['com.instagram.android'], 45);
    });

    test('Delete limit removes entry', () async {
      await limitRepo.saveLimit('com.instagram.android', 30);
      await limitRepo.saveLimit('com.google.android.youtube', 60);

      var limits = await limitRepo.getLimits();
      expect(limits.length, 2);

      await limitRepo.deleteLimit('com.instagram.android');
      limits = await limitRepo.getLimits();
      expect(limits.length, 1);
      expect(limits['com.instagram.android'], isNull);
      expect(limits['com.google.android.youtube'], 60);
    });
  });

  group('SessionDatabase Version 1 to 2 Upgrade Migrations', () {
    test('onUpgrade successfully creates app_limits table from version 1', () async {
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'migration_test_${DateTime.now().millisecondsSinceEpoch}.db');

      // Open v1 database (only sessions table exists)
      final dbV1 = await openDatabase(
        path,
        version: 1,
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
        },
      );

      // Verify app_limits table does not exist yet (queries should fail)
      expect(
        dbV1.query('app_limits'),
        throwsA(isA<DatabaseException>()),
      );

      await dbV1.close();

      // Open the same database at version 2 to trigger onUpgrade
      final dbV2 = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          // onCreate won't run if the DB was already created
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
        },
      );

      // Verify app_limits table now exists and can be successfully queried
      final limits = await dbV2.query('app_limits');
      expect(limits, isEmpty);

      // Verify sessions table still exists and can be successfully queried
      final sessions = await dbV2.query('sessions');
      expect(sessions, isEmpty);

      await dbV2.close();
      await databaseFactory.deleteDatabase(path);
    });

    test('onUpgrade successfully creates contracts, contract_apps, and contract_days tables from version 2', () async {
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'migration_test_v2_v3_${DateTime.now().millisecondsSinceEpoch}.db');

      // Open v2 database (only sessions and app_limits exist)
      final dbV2 = await openDatabase(
        path,
        version: 2,
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
        },
      );

      // Verify contracts table does not exist yet (queries should fail)
      expect(
        dbV2.query('contracts'),
        throwsA(isA<DatabaseException>()),
      );

      await dbV2.close();

      // Open the same database at version 3 via custom openDatabase to trigger onUpgrade
      final dbV3 = await openDatabase(
        path,
        version: 3,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {},
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE contracts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                duration_days INTEGER NOT NULL,
                start_timestamp_utc TEXT NOT NULL,
                end_timestamp_utc TEXT NOT NULL,
                completed_at_utc TEXT,
                longest_streak INTEGER DEFAULT 0,
                current_streak INTEGER DEFAULT 0,
                status TEXT NOT NULL
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
                FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE,
                UNIQUE(contract_id, date_utc)
              )
            ''');
          }
        },
      );

      // Verify new tables now exist and can be successfully queried
      expect(await dbV3.query('contracts'), isEmpty);
      expect(await dbV3.query('contract_apps'), isEmpty);
      expect(await dbV3.query('contract_days'), isEmpty);

      // Verify app_limits and sessions tables still exist
      expect(await dbV3.query('app_limits'), isEmpty);
      expect(await dbV3.query('sessions'), isEmpty);

      await dbV3.close();
      await databaseFactory.deleteDatabase(path);
    });

    test('onUpgrade successfully adds restriction_mode column to contract_apps from version 8', () async {
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'migration_test_v8_v9_${DateTime.now().millisecondsSinceEpoch}.db');

      final dbV8 = await openDatabase(
        path,
        version: 8,
        onCreate: (db, version) async {
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
              FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE
            )
          ''');
        },
      );

      await dbV8.insert('contract_apps', {
        'contract_id': 1,
        'package_name': 'com.instagram.android',
        'daily_limit_seconds': 1200,
        'total_credits_seconds': 6000,
        'remaining_credits_seconds': 6000,
      });

      expect(
        () async => await dbV8.query('contract_apps', columns: ['restriction_mode']),
        throwsA(isA<DatabaseException>()),
      );

      await dbV8.close();

      final dbV9 = await openDatabase(
        path,
        version: 9,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 9) {
            try {
              await db.execute("ALTER TABLE contract_apps ADD COLUMN restriction_mode TEXT DEFAULT 'time_limit'");
            } catch (e) {
              // Ignore
            }
          }
        },
      );

      final apps = await dbV9.query('contract_apps');
      expect(apps.first['restriction_mode'], 'time_limit');

      await dbV9.close();
      await databaseFactory.deleteDatabase(path);
    });
  });
}
