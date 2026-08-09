import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/application/contract_controller.dart';
import '../../contract/data/contract_repository.dart';
import '../../contract/domain/contract.dart';
import '../../contract/domain/contract_app.dart';
import '../../contract/domain/contract_day_record.dart';
import '../../settings/application/partner_controller.dart';
import '../data/protection_platform_service.dart';

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final contractRepo = ref.watch(contractRepositoryProvider);
  final isFirebase = ref.watch(firebaseInitializedProvider);
  final firestore = isFirebase ? FirebaseFirestore.instance : null;
  return CloudSyncService(
    contractRepository: contractRepo,
    firestore: firestore,
    ref: ref,
  );
});

class CloudSyncService {
  final ContractRepository _contractRepository;
  final FirebaseFirestore? _firestore;
  final Ref _ref;
  bool _isSyncing = false;

  CloudSyncService({
    required ContractRepository contractRepository,
    required FirebaseFirestore? firestore,
    required Ref ref,
  })  : _contractRepository = contractRepository,
        _firestore = firestore,
        _ref = ref;

  Future<void> syncContract(String userId, Contract contract) async {
    if (_isSyncing) return;
    if (_firestore == null) {
      debugPrint('Cloud Sync: Firestore is not available. Skipping sync.');
      return;
    }
    _isSyncing = true;
    try {
      final contractIdStr = contract.id.toString();
      final docRef = _firestore!
          .collection('users')
          .doc(userId)
          .collection('contracts')
          .doc(contractIdStr);

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final remoteData = docSnapshot.data()!;
        final remoteUpdatedAtStr = remoteData['updated_at_utc'] as String?;
        final localUpdatedAt = contract.updatedAtUtc;

        if (remoteUpdatedAtStr != null && localUpdatedAt != null) {
          final remoteUpdatedAt = DateTime.parse(remoteUpdatedAtStr).toUtc();
          if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
            // Cloud copy is newer, download and rehydrate it locally!
            debugPrint('Conflict resolution: Cloud copy is newer. Triggering rehydration.');
            _isSyncing = false;
            await checkForActiveContractAndRehydrate(userId);
            return;
          }
        }
      }

      // Get days to upload
      final days = await _contractRepository.getContractDays(contract.id!);

      final batch = _firestore.batch();
      
      // Sync main contract
      batch.set(docRef, {
        'durationDays': contract.durationDays,
        'startTimestampUtc': contract.startTimestampUtc.toIso8601String(),
        'endTimestampUtc': contract.endTimestampUtc.toIso8601String(),
        'completedAtUtc': contract.completedAtUtc?.toIso8601String(),
        'status': contract.status.name,
        'longestStreak': contract.longestStreak,
        'currentStreak': contract.currentStreak,
        'updated_at_utc': contract.updatedAtUtc?.toIso8601String() ?? DateTime.now().toUtc().toIso8601String(),
      });

      // Write subcollection apps
      for (final app in contract.apps) {
        final appRef = docRef.collection('apps').doc(app.packageName);
        batch.set(appRef, {
          'packageName': app.packageName,
          'dailyLimitSeconds': app.dailyLimit.inSeconds,
          'totalCreditsSeconds': app.totalCredits.inSeconds,
          'remainingCreditsSeconds': app.remainingCredits.inSeconds,
          'restrictionMode': app.restrictionMode.name,
        });
      }

      // Write subcollection days
      for (final day in days) {
        final dayRef = docRef.collection('days').doc(day.dateUtc);
        batch.set(dayRef, {
          'dateUtc': day.dateUtc,
          'status': day.status.name,
          'creditsDeducted': day.creditsDeducted ? 1 : 0,
        });
      }

      await batch.commit();
      debugPrint('Cloud Sync: Upload completed for contract ${contract.id}');
    } catch (e) {
      debugPrint('Cloud Sync: Upload failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Verifies if an active contract exists in Firestore and rehydrates local database and native shields.
  Future<bool> checkForActiveContractAndRehydrate(String userId) async {
    try {
      // 1. Check if we already have an active contract in local database.
      final localActive = await _contractRepository.getActiveContract();
      if (localActive != null) {
        return true;
      }

      if (_firestore == null) {
        debugPrint('Cloud Sync: Firestore is not available. Skipping active contract rehydration check.');
        return false;
      }

      // 2. Query Firestore for an active contract for this user.
      final query = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('contracts')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return false;
      }

      final doc = query.docs.first;
      final remoteContractId = int.tryParse(doc.id) ?? 1;
      final data = doc.data();

      // 3. Retrieve remote apps from subcollection.
      final appsQuery = await doc.reference.collection('apps').get();
      final List<ContractApp> apps = [];
      for (final appDoc in appsQuery.docs) {
        final appData = appDoc.data();
        apps.add(ContractApp(
          packageName: appData['packageName'] as String,
          dailyLimit: Duration(seconds: appData['dailyLimitSeconds'] as int),
          totalCredits: Duration(seconds: appData['totalCreditsSeconds'] as int),
          remainingCredits: Duration(seconds: appData['remainingCreditsSeconds'] as int),
          restrictionMode: ContractApp.parseMode(appData['restrictionMode'] as String?),
        ));
      }

      // 4. Retrieve remote days from subcollection.
      final daysQuery = await doc.reference.collection('days').get();
      final List<ContractDayRecord> days = [];
      for (final dayDoc in daysQuery.docs) {
        final dayData = dayDoc.data();
        days.add(ContractDayRecord(
          contractId: remoteContractId,
          dateUtc: dayData['dateUtc'] as String,
          status: ContractDayStatus.values.firstWhere(
            (e) => e.name == dayData['status'] as String,
            orElse: () => ContractDayStatus.green,
          ),
          creditsDeducted: (dayData['creditsDeducted'] as int? ?? 0) == 1,
        ));
      }

      final contract = Contract(
        id: remoteContractId,
        durationDays: data['durationDays'] as int,
        startTimestampUtc: DateTime.parse(data['startTimestampUtc'] as String),
        endTimestampUtc: DateTime.parse(data['endTimestampUtc'] as String),
        completedAtUtc: data['completedAtUtc'] != null
            ? DateTime.parse(data['completedAtUtc'] as String)
            : null,
        longestStreak: data['longestStreak'] as int,
        currentStreak: data['currentStreak'] as int,
        status: ContractStatus.active,
        apps: apps,
        updatedAtUtc: data['updated_at_utc'] != null
            ? DateTime.parse(data['updated_at_utc'] as String)
            : null,
      );

      // 5. Rehydrate local SQLite database.
      await _contractRepository.rehydrateContract(contract, days);

      // 6. Enforce and verify native limits.
      final platformService = _ref.read(protectionPlatformServiceProvider);
      for (final app in apps) {
        final success = await platformService.setAppLimit(
          app.packageName,
          app.dailyLimit.inSeconds,
          app.restrictionMode.name,
        );
        if (!success) {
          throw Exception('Failed to set native limit for package ${app.packageName}');
        }
      }

      // Restore active contract status native side
      await platformService.updateActiveContractStatus(true);

      // 7. Force Riverpod to reload states.
      _ref.invalidate(activeContractProvider);
      
      debugPrint('Cloud Sync: Rehydration successful for contract ${contract.id}');
      return true;
    } catch (e) {
      debugPrint('Cloud Sync: Rehydration failed: $e');
      rethrow;
    }
  }
}
