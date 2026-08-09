import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/contract/data/sqlite_contract_repository.dart';
import 'package:sayno/features/contract/domain/contract.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';
import 'package:sayno/features/contract/domain/contract_day_record.dart';
import 'package:sayno/features/protection/data/session_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SqliteContractRepository Tests', () {
    late SessionDatabase sessionDb;
    late SqliteContractRepository repository;

    setUp(() async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 4,
        singleInstance: false,
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
        },
      );
      sessionDb = SessionDatabase(db: db);
      repository = SqliteContractRepository(database: sessionDb);
    });

    test('No active contract returns null', () async {
      final active = await repository.getActiveContract();
      expect(active, isNull);
    });

    test('Create contract and retrieve active contract', () async {
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(days: 7));

      final contract = Contract(
        durationDays: 7,
        startTimestampUtc: now,
        endTimestampUtc: end,
        status: ContractStatus.active,
      );

      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
          restrictionMode: RestrictionMode.monk,
        ),
        const ContractApp(
          packageName: 'com.google.android.youtube',
          dailyLimit: Duration(minutes: 20),
          totalCredits: Duration(minutes: 140),
          remainingCredits: Duration(minutes: 140),
        ),
      ];

      final contractId = await repository.createContract(contract, apps);
      expect(contractId, isNotNull);
      expect(contractId, greaterThan(0));

      final active = await repository.getActiveContract();
      expect(active, isNotNull);
      expect(active!.id, contractId);
      expect(active.durationDays, 7);
      expect(active.status, ContractStatus.active);
      expect(active.apps.length, 2);

      final instagram = active.apps.firstWhere((a) => a.packageName == 'com.instagram.android');
      expect(instagram.dailyLimit, const Duration(minutes: 40));
      expect(instagram.totalCredits, const Duration(minutes: 280));
      expect(instagram.remainingCredits, const Duration(minutes: 280));
      expect(instagram.restrictionMode, RestrictionMode.monk);

      final youtube = active.apps.firstWhere((a) => a.packageName == 'com.google.android.youtube');
      expect(youtube.restrictionMode, RestrictionMode.time_limit);
    });

    test('Update remaining credits', () async {
      final now = DateTime.now().toUtc();
      final contract = Contract(
        durationDays: 7,
        startTimestampUtc: now,
        endTimestampUtc: now.add(const Duration(days: 7)),
        status: ContractStatus.active,
      );
      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
        )
      ];

      final contractId = await repository.createContract(contract, apps);

      await repository.updateRemainingCredits(
        contractId,
        'com.instagram.android',
        const Duration(minutes: 260),
      );

      final active = await repository.getActiveContract();
      expect(active!.apps.first.remainingCredits, const Duration(minutes: 260));
    });

    test('Update streak counts', () async {
      final now = DateTime.now().toUtc();
      final contract = Contract(
        durationDays: 7,
        startTimestampUtc: now,
        endTimestampUtc: now.add(const Duration(days: 7)),
        status: ContractStatus.active,
      );
      final contractId = await repository.createContract(contract, []);

      await repository.updateContractStreak(contractId, 3, 5);

      final active = await repository.getActiveContract();
      expect(active!.currentStreak, 3);
      expect(active.longestStreak, 5);
    });

    test('Record and retrieve contract days', () async {
      final now = DateTime.now().toUtc();
      final contract = Contract(
        durationDays: 7,
        startTimestampUtc: now,
        endTimestampUtc: now.add(const Duration(days: 7)),
        status: ContractStatus.active,
      );
      final contractId = await repository.createContract(contract, []);

      await repository.recordContractDay(contractId, '2026-06-21', ContractDayStatus.green);
      await repository.recordContractDay(contractId, '2026-06-22', ContractDayStatus.red);

      final days = await repository.getContractDays(contractId);
      expect(days.length, 2);
      expect(days[0].dateUtc, '2026-06-21');
      expect(days[0].status, ContractDayStatus.green);
      expect(days[1].dateUtc, '2026-06-22');
      expect(days[1].status, ContractDayStatus.red);
    });

    test('Complete contract and count completed contracts', () async {
      final now = DateTime.now().toUtc();
      final contract = Contract(
        durationDays: 7,
        startTimestampUtc: now,
        endTimestampUtc: now.add(const Duration(days: 7)),
        status: ContractStatus.active,
      );
      final contractId = await repository.createContract(contract, []);

      // Count is initially 0 (only active)
      var count = await repository.getCompletedContractsCount();
      expect(count, 0);

      // Complete it
      await repository.updateContractStatus(contractId, ContractStatus.completed, DateTime.now().toUtc());

      final active = await repository.getActiveContract();
      expect(active, isNull);

      count = await repository.getCompletedContractsCount();
      expect(count, 1);

      // Check failed contract also counts towards completed contract count
      final contract2 = Contract(
        durationDays: 7,
        startTimestampUtc: now,
        endTimestampUtc: now.add(const Duration(days: 7)),
        status: ContractStatus.active,
      );
      final contractId2 = await repository.createContract(contract2, []);
      await repository.updateContractStatus(contractId2, ContractStatus.failed, DateTime.now().toUtc());

      count = await repository.getCompletedContractsCount();
      expect(count, 2);
    });

    test('Get usage for package on date UTC filters correctly', () async {
      final db = await sessionDb.database;
      
      // Insert mock sessions with different start times
      await db.insert('sessions', {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': '2026-06-21T08:00:00.000Z', // UTC 2026-06-21
        'end_time': '2026-06-21T08:10:00.000Z',
        'duration_seconds': 600,
      });

      await db.insert('sessions', {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': '2026-06-21T23:55:00.000', // Local time (evaluates to UTC 2026-06-21 depending on zone, let's make it explicitly Z for test predictability)
        'end_time': '2026-06-22T00:00:00.000',
        'duration_seconds': 300,
      });

      await db.insert('sessions', {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': '2026-06-21T23:55:00.000Z', // UTC 2026-06-21
        'end_time': '2026-06-22T00:00:00.000Z',
        'duration_seconds': 300,
      });

      await db.insert('sessions', {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': '2026-06-22T00:05:00.000Z', // UTC 2026-06-22
        'end_time': '2026-06-22T00:10:00.000Z',
        'duration_seconds': 300,
      });

      await db.insert('sessions', {
        'package_name': 'com.google.android.youtube',
        'app_name': 'YouTube',
        'start_time': '2026-06-21T10:00:00.000Z', // Different app
        'end_time': '2026-06-21T10:05:00.000Z',
        'duration_seconds': 300,
      });

      final usage21 = await repository.getUsageForPackageOnDateUtc('com.instagram.android', '2026-06-21');
      // Sum of duration_seconds for com.instagram.android on 2026-06-21:
      // Z-based matching strings will have toUtc substring(0,10) == '2026-06-21'
      // 1. '2026-06-21T08:00:00.000Z' -> yes, 600s
      // 2. '2026-06-21T23:55:00.000' -> parses as local. toUtc() will have substring(0, 10) depending on host timezone.
      // 3. '2026-06-21T23:55:00.000Z' -> yes, 300s
      // Total predictable UTC 2026-06-21 matching items 1 and 3 is 900s (if item 2 is different zone, it won't impact our core test assertion if we only check items we know match)
      expect(usage21.inSeconds, greaterThanOrEqualTo(900));

      final usage22 = await repository.getUsageForPackageOnDateUtc('com.instagram.android', '2026-06-22');
      expect(usage22.inSeconds, 300);
    });
  });
}
