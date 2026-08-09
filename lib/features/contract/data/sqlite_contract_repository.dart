import 'package:sqflite/sqflite.dart';
import '../../protection/data/session_database.dart';
import '../domain/contract.dart';
import '../domain/contract_app.dart';
import '../domain/contract_day_record.dart';
import 'contract_repository.dart';

class SqliteContractRepository implements ContractRepository {
  final SessionDatabase _sessionDatabase;

  SqliteContractRepository({required SessionDatabase database})
      : _sessionDatabase = database;

  @override
  Future<Contract?> getActiveContract() async {
    final db = await _sessionDatabase.database;

    final contractMaps = await db.query(
      'contracts',
      where: 'status = ?',
      whereArgs: [ContractStatus.active.name],
    );

    if (contractMaps.isEmpty) return null;

    final contractMap = contractMaps.first;
    final contractId = contractMap['id'] as int;

    final appMaps = await db.query(
      'contract_apps',
      where: 'contract_id = ?',
      whereArgs: [contractId],
    );

    final apps = appMaps.map(_mapToContractApp).toList();
    return _mapToContract(contractMap, apps);
  }

  @override
  Future<int> createContract(Contract contract, List<ContractApp> apps) async {
    final db = await _sessionDatabase.database;

    return await db.transaction((txn) async {
      final contractId = await txn.insert('contracts', {
        'duration_days': contract.durationDays,
        'start_timestamp_utc': contract.startTimestampUtc.toIso8601String(),
        'end_timestamp_utc': contract.endTimestampUtc.toIso8601String(),
        'completed_at_utc': contract.completedAtUtc?.toIso8601String(),
        'longest_streak': contract.longestStreak,
        'current_streak': contract.currentStreak,
        'status': contract.status.name,
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      });

      for (final app in apps) {
        await txn.insert('contract_apps', {
          'contract_id': contractId,
          'package_name': app.packageName,
          'daily_limit_seconds': app.dailyLimit.inSeconds,
          'total_credits_seconds': app.totalCredits.inSeconds,
          'remaining_credits_seconds': app.remainingCredits.inSeconds,
          'restriction_mode': app.restrictionMode.name,
        });
      }

      return contractId;
    });
  }

  @override
  Future<void> updateContractStreak(
    int contractId,
    int currentStreak,
    int longestStreak,
  ) async {
    final db = await _sessionDatabase.database;
    await db.update(
      'contracts',
      {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [contractId],
    );
  }

  @override
  Future<void> updateRemainingCredits(
    int contractId,
    String packageName,
    Duration remaining,
  ) async {
    final db = await _sessionDatabase.database;
    await db.transaction((txn) async {
      await txn.update(
        'contract_apps',
        {
          'remaining_credits_seconds': remaining.inSeconds,
        },
        where: 'contract_id = ? AND package_name = ?',
        whereArgs: [contractId, packageName],
      );
      await txn.update(
        'contracts',
        {
          'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [contractId],
      );
    });
  }

  @override
  Future<void> recordContractDay(
    int contractId,
    String dateUtc,
    ContractDayStatus status, {
    bool creditsDeducted = false,
  }) async {
    final db = await _sessionDatabase.database;
    await db.transaction((txn) async {
      await txn.insert(
        'contract_days',
        {
          'contract_id': contractId,
          'date_utc': dateUtc,
          'status': status.name,
          'credits_deducted': creditsDeducted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'contracts',
        {
          'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [contractId],
      );
    });
  }

  @override
  Future<List<ContractDayRecord>> getContractDays(int contractId) async {
    final db = await _sessionDatabase.database;
    final maps = await db.query(
      'contract_days',
      where: 'contract_id = ?',
      whereArgs: [contractId],
      orderBy: 'date_utc ASC',
    );
    return maps.map(_mapToContractDayRecord).toList();
  }

  @override
  Future<void> updateContractStatus(
    int contractId,
    ContractStatus status,
    DateTime completedAtUtc,
  ) async {
    final db = await _sessionDatabase.database;
    await db.update(
      'contracts',
      {
        'status': status.name,
        'completed_at_utc': completedAtUtc.toIso8601String(),
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [contractId],
    );
  }

  @override
  Future<int> getCompletedContractsCount() async {
    final db = await _sessionDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM contracts WHERE status = ? OR status = ?',
      [ContractStatus.completed.name, ContractStatus.failed.name],
    );
    final count = result.first['count'];
    return (count as int?) ?? 0;
  }

  @override
  Future<Duration> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async {
    final db = await _sessionDatabase.database;
    final maps = await db.query(
      'sessions',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    int totalSeconds = 0;
    for (final map in maps) {
      final startTimeStr = map['start_time'] as String;
      final startTime = DateTime.parse(startTimeStr).toUtc();
      final itemDateUtcStr = startTime.toIso8601String().substring(0, 10);
      if (itemDateUtcStr == dateUtc) {
        totalSeconds += map['duration_seconds'] as int;
      }
    }
    return Duration(seconds: totalSeconds);
  }

  Contract _mapToContract(Map<String, dynamic> map, List<ContractApp> apps) {
    return Contract(
      id: map['id'] as int,
      durationDays: map['duration_days'] as int,
      startTimestampUtc: DateTime.parse(map['start_timestamp_utc'] as String),
      endTimestampUtc: DateTime.parse(map['end_timestamp_utc'] as String),
      completedAtUtc: map['completed_at_utc'] != null
          ? DateTime.parse(map['completed_at_utc'] as String)
          : null,
      longestStreak: map['longest_streak'] as int,
      currentStreak: map['current_streak'] as int,
      status: ContractStatus.values.firstWhere(
        (e) => e.name == map['status'] as String,
        orElse: () => ContractStatus.active,
      ),
      apps: apps,
      updatedAtUtc: map['updated_at_utc'] != null
          ? DateTime.parse(map['updated_at_utc'] as String)
          : null,
    );
  }

  @override
  Future<void> rehydrateContract(Contract contract, List<ContractDayRecord> days) async {
    final db = await _sessionDatabase.database;
    await db.transaction((txn) async {
      await txn.delete('contracts', where: 'id = ?', whereArgs: [contract.id]);
      await txn.delete('contract_apps', where: 'contract_id = ?', whereArgs: [contract.id]);
      await txn.delete('contract_days', where: 'contract_id = ?', whereArgs: [contract.id]);

      await txn.insert('contracts', {
        'id': contract.id,
        'duration_days': contract.durationDays,
        'start_timestamp_utc': contract.startTimestampUtc.toIso8601String(),
        'end_timestamp_utc': contract.endTimestampUtc.toIso8601String(),
        'completed_at_utc': contract.completedAtUtc?.toIso8601String(),
        'longest_streak': contract.longestStreak,
        'current_streak': contract.currentStreak,
        'status': contract.status.name,
        'updated_at_utc': contract.updatedAtUtc?.toIso8601String(),
      });

      for (final app in contract.apps) {
        await txn.insert('contract_apps', {
          'contract_id': contract.id,
          'package_name': app.packageName,
          'daily_limit_seconds': app.dailyLimit.inSeconds,
          'total_credits_seconds': app.totalCredits.inSeconds,
          'remaining_credits_seconds': app.remainingCredits.inSeconds,
          'restriction_mode': app.restrictionMode.name,
        });
      }

      for (final day in days) {
        await txn.insert('contract_days', {
          'contract_id': contract.id,
          'date_utc': day.dateUtc,
          'status': day.status.name,
          'credits_deducted': day.creditsDeducted ? 1 : 0,
        });
      }
    });
  }

  ContractApp _mapToContractApp(Map<String, dynamic> map) {
    return ContractApp(
      id: map['id'] as int,
      contractId: map['contract_id'] as int,
      packageName: map['package_name'] as String,
      dailyLimit: Duration(seconds: map['daily_limit_seconds'] as int),
      totalCredits: Duration(seconds: map['total_credits_seconds'] as int),
      remainingCredits: Duration(seconds: map['remaining_credits_seconds'] as int),
      restrictionMode: ContractApp.parseMode(map['restriction_mode'] as String?),
    );
  }

  ContractDayRecord _mapToContractDayRecord(Map<String, dynamic> map) {
    return ContractDayRecord(
      id: map['id'] as int,
      contractId: map['contract_id'] as int,
      dateUtc: map['date_utc'] as String,
      status: ContractDayStatus.values.firstWhere(
        (e) => e.name == map['status'] as String,
        orElse: () => ContractDayStatus.green,
      ),
      creditsDeducted: (map['credits_deducted'] as int? ?? 0) == 1,
    );
  }
}
