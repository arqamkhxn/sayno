import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayno/features/contract/application/contract_controller.dart';
import 'package:sayno/features/contract/data/contract_repository.dart';
import 'package:sayno/features/contract/data/sqlite_contract_repository.dart';
import 'package:sayno/features/contract/domain/contract.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';
import 'package:sayno/features/contract/domain/contract_day_record.dart';
import 'package:sayno/features/protection/application/protection_controller.dart';
import 'package:sayno/features/protection/application/session_controller.dart';
import 'package:sayno/features/protection/application/limit_controller.dart';
import 'package:sayno/features/protection/data/session_database.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeProtectionPlatformService implements ProtectionPlatformService {
  final Map<String, int> limits = {};
  final Map<String, String> modes = {};
  final Map<String, int> usage = {};
  final Map<String, Map<String, int>> dateUsage = {};
  ContractRepository? repo;

  @override
  Future<bool> setAppLimit(String packageName, int limitSeconds, String restrictionMode) async {
    limits[packageName] = limitSeconds;
    modes[packageName] = restrictionMode;
    return true;
  }

  @override
  Future<bool> removeAppLimit(String packageName) async {
    limits.remove(packageName);
    return true;
  }

  final Map<String, Map<String, int>> dateUsageMap = {};

  @override
  Future<int> getUsage(String packageName) async {
    return usage[packageName] ?? 0;
  }

  @override
  Future<int> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async {
    final val = dateUsage[dateUtc]?[packageName] ?? usage[packageName];
    if (val != null) return val;
    if (repo != null) {
      final dbUsage = await repo!.getUsageForPackageOnDateUtc(packageName, dateUtc);
      return dbUsage.inSeconds;
    }
    return 0;
  }

  @override
  Future<Map<String, int>> getAllUsage() async {
    return usage;
  }

  @override
  Future<bool> isClockManipulated() async => false;

  @override
  Future<bool> isAccessibilityEnabled() async => true;
  @override
  Future<bool> isScreenOn() async => true;
  @override
  Future<bool> isDeviceLocked() async => false;
  @override
  Future<bool> openAccessibilitySettings() async => true;
  @override
  Future<bool> updateMonitoredApps(List<String> packageNames) async => true;
  @override
  Future<bool> updateHighRiskApps(List<String> packageNames) async => true;
  @override
  Future<bool> updateKeywords(List<String> keywords) async => true;
  @override
  Future<bool> performBack() async => true;
  @override
  Future<bool> performHome() async => true;
  @override
  Future<bool> triggerRescan() async => true;
  @override
  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {}

  @override
  Future<bool> updateVerifiedTime(int epochSeconds) async => true;

  @override
  Future<bool> updateActiveContractStatus(bool isActive) async => true;

  @override
  Future<bool> updateReleaseAuthorization(bool isAuthorized) async => true;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ActiveContractNotifier & Providers Tests', () {
    late SessionDatabase sessionDb;
    late FakeProtectionPlatformService fakePlatformService;
    late ProviderContainer container;

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
      fakePlatformService = FakeProtectionPlatformService();

      container = ProviderContainer(
        overrides: [
          sessionDatabaseProvider.overrideWithValue(sessionDb),
          protectionPlatformServiceProvider.overrideWithValue(fakePlatformService),
        ],
      );
      fakePlatformService.repo = container.read(contractRepositoryProvider);

      // Reset mock clock
      getSystemTime = () => DateTime.utc(2026, 6, 21, 10, 0, 0);
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial active contract is null', () async {
      final active = await container.read(activeContractProvider.future);
      expect(active, isNull);
    });

    test('Create contract saves to db and registers native limits', () async {
      final notifier = container.read(activeContractProvider.notifier);

      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
          restrictionMode: RestrictionMode.focus,
        )
      ];

      await notifier.createContract(7, apps);

      final active = await container.read(activeContractProvider.future);
      expect(active, isNotNull);
      expect(active!.durationDays, 7);
      expect(active.apps.length, 1);
      expect(active.apps.first.packageName, 'com.instagram.android');
      expect(active.apps.first.restrictionMode, RestrictionMode.focus);

      // Native limit verified
      expect(fakePlatformService.limits['com.instagram.android'], 2400); // 40 mins = 2400 seconds
      expect(fakePlatformService.modes['com.instagram.android'], 'focus');
    });

    test('Borrow minutes reduces credits, resets streak, records Red day, and extends native limit', () async {
      final notifier = container.read(activeContractProvider.notifier);
      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
        )
      ];

      await notifier.createContract(7, apps);
      
      // Simulate today's native usage is at limit
      fakePlatformService.usage['com.instagram.android'] = 2400; // 40 minutes

      // Borrow 20 minutes
      await notifier.borrowMinutes('com.instagram.android', const Duration(minutes: 20));

      final active = await container.read(activeContractProvider.future);
      expect(active!.apps.first.remainingCredits, const Duration(minutes: 260));
      expect(active.currentStreak, 0);

      // Verify Red day is recorded for today (2026-06-21)
      final calendar = await container.read(contractCalendarProvider(active.id!).future);
      expect(calendar.length, 1);
      expect(calendar.first.dateUtc, '2026-06-21');
      expect(calendar.first.status, ContractDayStatus.red);

      // Verify native limit extended to current usage (2400) + 20 mins (1200) = 3600 seconds
      expect(fakePlatformService.limits['com.instagram.android'], 3600);
    });

    test('Validation service marks previous days green or red and updates streaks', () async {
      final notifier = container.read(activeContractProvider.notifier);
      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
        )
      ];

      // Contract starts on 2026-06-21 in UTC
      await notifier.createContract(7, apps);

      final active = await container.read(activeContractProvider.future);
      final db = await sessionDb.database;

      // Insert some mock sessions for yesterday (2026-06-21) - User used 30 minutes (Green day)
      await db.insert('sessions', {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': '2026-06-21T12:00:00.000Z',
        'end_time': '2026-06-21T12:30:00.000Z',
        'duration_seconds': 1800,
      });

      // Shift clock forward to tomorrow (2026-06-22 10:00:00) so yesterday is fully completed
      getSystemTime = () => DateTime.utc(2026, 6, 22, 10, 0, 0);

      final validationService = container.read(contractValidationServiceProvider);
      await validationService.performValidation();

      Contract? updated = await container.read(activeContractProvider.future);
      expect(updated!.currentStreak, 1);
      expect(updated.longestStreak, 1);

      var calendar = await container.read(contractCalendarProvider(active!.id!).future);
      expect(calendar.length, 1);
      expect(calendar.first.dateUtc, '2026-06-21');
      expect(calendar.first.status, ContractDayStatus.green);

      // Now insert sessions for the next day (2026-06-22) - Exceeded 40 minutes (Red day)
      await db.insert('sessions', {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'start_time': '2026-06-22T14:00:00.000Z',
        'end_time': '2026-06-22T14:50:00.000Z',
        'duration_seconds': 3000, // 50 mins
      });

      // Shift clock forward again to 2026-06-23
      getSystemTime = () => DateTime.utc(2026, 6, 23, 10, 0, 0);
      await validationService.performValidation();

      final updated2 = await container.read(activeContractProvider.future);
      expect(updated2!.currentStreak, 0); // Reset streak
      expect(updated2.longestStreak, 1);  // Retained longest streak

      calendar = await container.read(contractCalendarProvider(active!.id!).future);
      print("SAYNO_DEBUG: calendar length after second validation: ${calendar.length}");
      for (var d in calendar) {
        print("SAYNO_DEBUG: calendar item: ${d.dateUtc} - ${d.status}");
      }
      expect(calendar.length, 2);
      expect(calendar[1].dateUtc, '2026-06-22');
      expect(calendar[1].status, ContractDayStatus.red);
    });

    test('Archiving active contract updates status and cleans up native limits', () async {
      final notifier = container.read(activeContractProvider.notifier);
      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
        )
      ];

      await notifier.createContract(7, apps);
      
      final active = await container.read(activeContractProvider.future);
      expect(active, isNotNull);

      // Complete/archive active contract
      await notifier.completeActiveContract(ContractStatus.completed);

      final currentActive = await container.read(activeContractProvider.future);
      expect(currentActive, isNull);

      // Verified contract app limit is removed from native platform
      expect(fakePlatformService.limits['com.instagram.android'], isNull);

      final completedCount = await container.read(completedContractsCountProvider.future);
      expect(completedCount, 1);
    });

    test('Daily credit consumption math - Standard vs Borrowed Days', () async {
      final notifier = container.read(activeContractProvider.notifier);
      final apps = [
        const ContractApp(
          packageName: 'com.instagram.android',
          dailyLimit: Duration(minutes: 40),
          totalCredits: Duration(minutes: 280),
          remainingCredits: Duration(minutes: 280),
        )
      ];

      // Contract starts on 2026-06-21 in UTC
      await notifier.createContract(7, apps);

      final active = await container.read(activeContractProvider.future);
      expect(active, isNotNull);

      // --- Standard Day ---
      // User used 30 minutes on 2026-06-21.
      fakePlatformService.dateUsage['2026-06-21'] = {
        'com.instagram.android': 1800, // 30 mins
      };

      // Shift clock forward to 2026-06-22
      getSystemTime = () => DateTime.utc(2026, 6, 22, 10, 0, 0);

      final validationService = container.read(contractValidationServiceProvider);
      await validationService.performValidation();

      // Check remaining credits. Remaining should be 280m - 30m = 250m
      final standardDayUpdated = await container.read(activeContractProvider.future);
      expect(standardDayUpdated!.apps.first.remainingCredits, const Duration(minutes: 250));

      // --- Borrowed Day ---
      // User used their full limit and then borrowed 20 minutes on 2026-06-22.
      // Borrow action happens on 2026-06-22.
      fakePlatformService.usage['com.instagram.android'] = 2400; // 40 minutes used when borrow is clicked
      await notifier.borrowMinutes('com.instagram.android', const Duration(minutes: 20));

      // Borrow action immediately deducts 20 minutes from the pool: 250m - 20m = 230m
      final borrowUpdated = await container.read(activeContractProvider.future);
      expect(borrowUpdated!.apps.first.remainingCredits, const Duration(minutes: 230));

      // User continues using the app on 2026-06-22 up to, say, 55 minutes total usage.
      fakePlatformService.dateUsage['2026-06-22'] = {
        'com.instagram.android': 3300, // 55 mins total usage on 2026-06-22
      };

      // Shift clock forward to 2026-06-23
      getSystemTime = () => DateTime.utc(2026, 6, 23, 10, 0, 0);
      await validationService.performValidation();

      // Validation at midnight UTC should deduct only min(actual_usage, daily_limit).
      // actual_usage = 55m, daily_limit = 40m. min(55, 40) = 40m.
      // Pool should be updated to: 230m - 40m = 190m.
      // (The extra 15m was already deducted during the borrow action, so no double counting occurs).
      final finalUpdated = await container.read(activeContractProvider.future);
      expect(finalUpdated!.apps.first.remainingCredits, const Duration(minutes: 190));
    });
  });
}
