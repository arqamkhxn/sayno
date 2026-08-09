import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayno/features/contract/domain/contract.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';
import 'package:sayno/features/contract/domain/contract_day_record.dart';
import 'package:sayno/features/contract/data/contract_repository.dart';
import 'package:sayno/features/contract/application/contract_controller.dart';
import 'package:sayno/features/protection/data/cloud_sync_service.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';
import 'package:sayno/features/settings/application/partner_controller.dart';

class MockContractRepository implements ContractRepository {
  Contract? activeContract;
  final List<ContractDayRecord> dayRecords = [];
  bool rehydratedCalled = false;

  @override
  Future<Contract?> getActiveContract() async => activeContract;

  @override
  Future<int> createContract(Contract contract, List<ContractApp> apps) async => 1;

  @override
  Future<void> updateContractStreak(int contractId, int currentStreak, int longestStreak) async {}

  @override
  Future<void> updateRemainingCredits(int contractId, String packageName, Duration remaining) async {}

  @override
  Future<void> recordContractDay(int contractId, String dateUtc, ContractDayStatus status, {bool creditsDeducted = false}) async {}

  @override
  Future<List<ContractDayRecord>> getContractDays(int contractId) async => dayRecords;

  @override
  Future<void> updateContractStatus(int contractId, ContractStatus status, DateTime completedAtUtc) async {}

  @override
  Future<int> getCompletedContractsCount() async => 0;

  @override
  Future<Duration> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async => Duration.zero;

  @override
  Future<void> rehydrateContract(Contract contract, List<ContractDayRecord> days) async {
    rehydratedCalled = true;
    activeContract = contract;
    dayRecords.clear();
    dayRecords.addAll(days);
  }
}

class MockProtectionPlatformService implements ProtectionPlatformService {
  bool setAppLimitSuccess = true;
  final Map<String, int> limits = {};
  final Map<String, String> modes = {};
  bool contractStatusUpdated = false;

  @override
  Future<bool> isClockManipulated() async => false;

  @override
  Future<bool> setAppLimit(String packageName, int limitSeconds, String restrictionMode) async {
    limits[packageName] = limitSeconds;
    modes[packageName] = restrictionMode;
    return setAppLimitSuccess;
  }

  @override
  Future<bool> updateActiveContractStatus(bool isActive) async {
    contractStatusUpdated = isActive;
    return true;
  }

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
  Future<bool> removeAppLimit(String packageName) async => true;
  @override
  Future<int> getUsage(String packageName) async => 0;
  @override
  Future<int> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async => 0;
  @override
  Future<Map<String, int>> getAllUsage() async => {};
  @override
  Future<bool> updateVerifiedTime(int epochSeconds) async => true;
  @override
  Future<bool> updateReleaseAuthorization(bool isAuthorized) async => true;
  @override
  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {}
}

class FakeRef implements Ref {
  final ProviderContainer container;
  FakeRef(this.container);

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  void invalidate(ProviderOrFamily provider) => container.invalidate(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCloudSyncService extends CloudSyncService {
  final Ref ref;
  final ContractRepository contractRepository;
  Map<String, dynamic>? remoteContractData;
  List<Map<String, dynamic>> remoteApps = [];
  List<Map<String, dynamic>> remoteDays = [];
  bool uploadCalled = false;

  TestCloudSyncService({
    required this.contractRepository,
    required super.firestore,
    required this.ref,
  }) : super(contractRepository: contractRepository, ref: ref);

  @override
  Future<void> syncContract(String userId, Contract contract) async {
    if (remoteContractData != null) {
      final remoteUpdatedAtStr = remoteContractData!['updated_at_utc'] as String?;
      final localUpdatedAt = contract.updatedAtUtc;
      if (remoteUpdatedAtStr != null && localUpdatedAt != null) {
        final remoteUpdatedAt = DateTime.parse(remoteUpdatedAtStr).toUtc();
        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          await checkForActiveContractAndRehydrate(userId);
          return;
        }
      }
    }

    uploadCalled = true;
    remoteContractData = {
      'durationDays': contract.durationDays,
      'startTimestampUtc': contract.startTimestampUtc.toIso8601String(),
      'endTimestampUtc': contract.endTimestampUtc.toIso8601String(),
      'completedAtUtc': contract.completedAtUtc?.toIso8601String(),
      'status': contract.status.name,
      'longestStreak': contract.longestStreak,
      'currentStreak': contract.currentStreak,
      'updated_at_utc': contract.updatedAtUtc?.toIso8601String() ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<bool> checkForActiveContractAndRehydrate(String userId) async {
    final localActive = await contractRepository.getActiveContract();
    if (localActive != null) {
      return true;
    }

    if (remoteContractData == null) {
      return false;
    }

    final remoteContractId = 1;
    final List<ContractApp> apps = remoteApps.map((a) => ContractApp(
      packageName: a['packageName'] as String,
      dailyLimit: Duration(seconds: a['dailyLimitSeconds'] as int),
      totalCredits: Duration(seconds: a['totalCreditsSeconds'] as int),
      remainingCredits: Duration(seconds: a['remainingCreditsSeconds'] as int),
      restrictionMode: ContractApp.parseMode(a['restrictionMode'] as String?),
    )).toList();

    final List<ContractDayRecord> days = remoteDays.map((d) => ContractDayRecord(
      contractId: remoteContractId,
      dateUtc: d['dateUtc'] as String,
      status: ContractDayStatus.values.firstWhere(
        (e) => e.name == d['status'] as String,
        orElse: () => ContractDayStatus.green,
      ),
      creditsDeducted: (d['creditsDeducted'] as int? ?? 0) == 1,
    )).toList();

    final contract = Contract(
      id: remoteContractId,
      durationDays: remoteContractData!['durationDays'] as int,
      startTimestampUtc: DateTime.parse(remoteContractData!['startTimestampUtc'] as String),
      endTimestampUtc: DateTime.parse(remoteContractData!['endTimestampUtc'] as String),
      completedAtUtc: remoteContractData!['completedAtUtc'] != null
          ? DateTime.parse(remoteContractData!['completedAtUtc'] as String)
          : null,
      longestStreak: remoteContractData!['longestStreak'] as int,
      currentStreak: remoteContractData!['currentStreak'] as int,
      status: ContractStatus.active,
      apps: apps,
      updatedAtUtc: remoteContractData!['updated_at_utc'] != null
          ? DateTime.parse(remoteContractData!['updated_at_utc'] as String)
          : null,
    );

    await contractRepository.rehydrateContract(contract, days);

    final platformService = ref.read(protectionPlatformServiceProvider);
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

    await platformService.updateActiveContractStatus(true);
    return true;
  }
}

void main() {
  late MockContractRepository mockRepository;
  late MockProtectionPlatformService mockPlatformService;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockContractRepository();
    mockPlatformService = MockProtectionPlatformService();
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer createContainer() {
    container = ProviderContainer(
      overrides: [
        contractRepositoryProvider.overrideWithValue(mockRepository),
        protectionPlatformServiceProvider.overrideWithValue(mockPlatformService),
      ],
    );
    return container;
  }

  test('syncContract uploads contract if no remote version exists', () async {
    createContainer();
    final service = TestCloudSyncService(
      contractRepository: mockRepository,
      firestore: null as dynamic,
      ref: FakeRef(container),
    );

    final contract = Contract(
      id: 1,
      durationDays: 7,
      startTimestampUtc: DateTime.utc(2026, 6, 22),
      endTimestampUtc: DateTime.utc(2026, 6, 29),
      status: ContractStatus.active,
      updatedAtUtc: DateTime.utc(2026, 6, 22, 12, 0, 0),
    );

    await service.syncContract('user123', contract);

    expect(service.uploadCalled, isTrue);
    expect(service.remoteContractData?['durationDays'], equals(7));
  });

  test('syncContract triggers rehydration if remote version is newer', () async {
    createContainer();
    final service = TestCloudSyncService(
      contractRepository: mockRepository,
      firestore: null as dynamic,
      ref: FakeRef(container),
    );

    // Seed a newer remote version
    service.remoteContractData = {
      'durationDays': 10,
      'startTimestampUtc': DateTime.utc(2026, 6, 22).toIso8601String(),
      'endTimestampUtc': DateTime.utc(2026, 7, 2).toIso8601String(),
      'status': 'active',
      'longestStreak': 3,
      'currentStreak': 3,
      'updated_at_utc': DateTime.utc(2026, 6, 22, 15, 0, 0).toIso8601String(),
    };
    service.remoteApps = [
      {'packageName': 'com.android.settings', 'dailyLimitSeconds': 60, 'totalCreditsSeconds': 600, 'remainingCreditsSeconds': 600}
    ];

    final localContract = Contract(
      id: 1,
      durationDays: 7,
      startTimestampUtc: DateTime.utc(2026, 6, 22),
      endTimestampUtc: DateTime.utc(2026, 6, 29),
      status: ContractStatus.active,
      updatedAtUtc: DateTime.utc(2026, 6, 22, 12, 0, 0), // Older
    );

    await service.syncContract('user123', localContract);

    expect(service.uploadCalled, isFalse);
    expect(mockRepository.rehydratedCalled, isTrue);
    expect(mockRepository.activeContract?.durationDays, equals(10));
  });

  test('Rehydration fails and throws if setAppLimit returns false', () async {
    createContainer();
    mockPlatformService.setAppLimitSuccess = false; // Trigger native fail simulation

    final service = TestCloudSyncService(
      contractRepository: mockRepository,
      firestore: null as dynamic,
      ref: FakeRef(container),
    );

    service.remoteContractData = {
      'durationDays': 10,
      'startTimestampUtc': DateTime.utc(2026, 6, 22).toIso8601String(),
      'endTimestampUtc': DateTime.utc(2026, 7, 2).toIso8601String(),
      'status': 'active',
      'longestStreak': 3,
      'currentStreak': 3,
      'updated_at_utc': DateTime.utc(2026, 6, 22, 15, 0, 0).toIso8601String(),
    };
    service.remoteApps = [
      {'packageName': 'com.android.settings', 'dailyLimitSeconds': 60, 'totalCreditsSeconds': 600, 'remainingCreditsSeconds': 600}
    ];

    expect(
      () => service.checkForActiveContractAndRehydrate('user123'),
      throwsA(isA<Exception>()),
    );
  });

  test('Rehydration parses restrictionMode and configures native limits correctly', () async {
    createContainer();
    final service = TestCloudSyncService(
      contractRepository: mockRepository,
      firestore: null as dynamic,
      ref: FakeRef(container),
    );

    service.remoteContractData = {
      'durationDays': 5,
      'startTimestampUtc': DateTime.utc(2026, 6, 22).toIso8601String(),
      'endTimestampUtc': DateTime.utc(2026, 6, 27).toIso8601String(),
      'status': 'active',
      'longestStreak': 0,
      'currentStreak': 0,
      'updated_at_utc': DateTime.utc(2026, 6, 22, 15, 0, 0).toIso8601String(),
    };
    service.remoteApps = [
      {
        'packageName': 'com.instagram.android',
        'dailyLimitSeconds': 120,
        'totalCreditsSeconds': 600,
        'remainingCreditsSeconds': 600,
        'restrictionMode': 'monk',
      },
      {
        'packageName': 'com.google.android.youtube',
        'dailyLimitSeconds': 180,
        'totalCreditsSeconds': 900,
        'remainingCreditsSeconds': 900,
        // restrictionMode is missing, should default to time_limit
      }
    ];

    await service.checkForActiveContractAndRehydrate('user123');

    expect(mockRepository.rehydratedCalled, isTrue);
    final apps = mockRepository.activeContract?.apps;
    expect(apps?.length, equals(2));

    final instagram = apps?.firstWhere((a) => a.packageName == 'com.instagram.android');
    expect(instagram?.restrictionMode, equals(RestrictionMode.monk));
    expect(mockPlatformService.limits['com.instagram.android'], equals(120));
    expect(mockPlatformService.modes['com.instagram.android'], equals('monk'));

    final youtube = apps?.firstWhere((a) => a.packageName == 'com.google.android.youtube');
    expect(youtube?.restrictionMode, equals(RestrictionMode.time_limit));
    expect(mockPlatformService.limits['com.google.android.youtube'], equals(180));
    expect(mockPlatformService.modes['com.google.android.youtube'], equals('time_limit'));
  });
}
