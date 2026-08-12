import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/session_controller.dart';
import 'package:sayno/features/protection/application/protection_controller.dart';
import 'package:sayno/features/protection/application/time_verification_service.dart';
import 'package:sayno/features/protection/application/notification_service.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';
import 'package:sayno/features/settings/application/release_controller.dart';

import 'package:sayno/features/settings/domain/partnership.dart';
import 'package:sayno/features/settings/data/partnership_repository.dart';
import 'package:sayno/features/settings/data/sqlite_partnership_repository.dart';
import 'package:sayno/features/settings/data/release_repository.dart';
import 'package:sayno/features/settings/data/sqlite_release_repository.dart';
import 'package:sayno/features/settings/domain/release_request.dart';
import 'package:fake_async/fake_async.dart';

class MockReleaseRepository implements ReleaseRepository {
  ReleaseRequest? activeRequest;
  final List<ReleaseRequest> history = [];

  @override
  Future<void> createReleaseRequest(ReleaseRequest request) async {
    final toSave = request.copyWith(id: history.length + 1);
    activeRequest = toSave;
    history.add(toSave);
  }

  @override
  Future<ReleaseRequest?> getActiveReleaseRequest() async {
    if (activeRequest == null) return null;
    final status = activeRequest!.status;
    if (status == ReleaseStatus.cooldown ||
        status == ReleaseStatus.pending_approval ||
        status == ReleaseStatus.grace_window) {
      return activeRequest;
    }
    return null;
  }

  @override
  Future<void> updateReleaseRequestStatus(int id, ReleaseStatus status) async {
    if (activeRequest != null && activeRequest!.id == id) {
      activeRequest = activeRequest!.copyWith(status: status);
    }
    final index = history.indexWhere((e) => e.id == id);
    if (index != -1) {
      history[index] = history[index].copyWith(status: status);
    }
  }

  @override
  Future<void> updateReleaseRequest(ReleaseRequest request) async {
    if (activeRequest != null && activeRequest!.id == request.id) {
      activeRequest = request;
    }
    final index = history.indexWhere((e) => e.id == request.id);
    if (index != -1) {
      history[index] = request;
    }
  }

  @override
  Future<List<ReleaseRequest>> getReleaseHistory() async {
    return history;
  }
}

class MockProtectionPlatformService implements ProtectionPlatformService {
  @override
  Future<List<Map<String, String>>> getInstalledApps() async => [];

  bool isAuthorized = false;

  @override
  Future<bool> isClockManipulated() async => false;

  @override
  Future<bool> updateReleaseAuthorization(bool authorized) async {
    isAuthorized = authorized;
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
  Future<bool> setAppLimit(String packageName, int limitSeconds, String restrictionMode) async => true;
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
  Future<bool> updateActiveContractStatus(bool isActive) async => true;
  @override
  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {}
}

class MockPartnershipRepository implements PartnershipRepository {
  Partnership? partnership;
  MockPartnershipRepository(this.partnership);

  @override
  Future<Partnership?> getLocalPartnership() async => partnership;

  @override
  Future<Partnership?> syncPartnership(String userId) async => partnership;

  @override
  Future<void> invitePartner({
    required String userEmail,
    required String userId,
    required String partnerEmail,
    required String verificationToken,
  }) async {}

  @override
  Future<void> acceptInvitation({
    required String token,
    required String partnerEmail,
    required String partnerUid,
  }) async {}

  @override
  Future<void> clearLocalPartnership() async {
    partnership = null;
  }
}

class MockTimeVerificationService implements TimeVerificationService {
  bool shouldThrow = false;
  Exception? toThrow;

  @override
  Future<void> verifyTimeIntegrity() async {
    if (shouldThrow) {
      throw toThrow ?? Exception('Mock time verification failed.');
    }
  }

  @override
  Future<bool> syncTime() async {
    return !shouldThrow;
  }
}

class MockNotificationService implements NotificationService {
  final List<Map<String, String>> sentNotifications = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showLocalNotification(String title, String body) async {}

  @override
  Future<void> sendNotificationToPartner({
    required String title,
    required String body,
  }) async {
    sentNotifications.add({'title': title, 'body': body});
  }

  @override
  void dispose() {}
}

void main() {
  late MockReleaseRepository mockRepository;
  late MockProtectionPlatformService mockPlatformService;
  late MockTimeVerificationService mockTimeService;
  late MockNotificationService mockNotificationService;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockReleaseRepository();
    mockPlatformService = MockProtectionPlatformService();
    mockTimeService = MockTimeVerificationService();
    mockNotificationService = MockNotificationService();
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer createContainer({Partnership? partnership}) {
    container = ProviderContainer(
      overrides: [
        releaseRepositoryProvider.overrideWithValue(mockRepository),
        protectionPlatformServiceProvider.overrideWithValue(mockPlatformService),
        timeVerificationServiceProvider.overrideWithValue(mockTimeService),
        partnershipRepositoryProvider.overrideWithValue(MockPartnershipRepository(partnership)),
        notificationServiceProvider.overrideWithValue(mockNotificationService),
      ],
    );
    return container;
  }

  test('Starts as null when no active request in DB', () async {
    createContainer();
    
    // Wait for the initialization future
    await container.read(releaseControllerProvider.notifier).loadActiveRequest();
    
    final state = container.read(releaseControllerProvider);
    expect(state.activeRequest, isNull);
    expect(state.remainingTime, isNull);
    expect(state.isLoading, isFalse);
  });

  test('Initiating a release creates a request and ticks the countdown', () {
    fakeAsync((async) {
      createContainer();
      
      final controller = container.read(releaseControllerProvider.notifier);
      final initialTime = DateTime.utc(2026, 6, 22, 12, 0, 0);
      getSystemTime = () => initialTime;

      controller.initiateRelease(durationSeconds: 10);
      async.flushMicrotasks();

      var state = container.read(releaseControllerProvider);
      expect(state.activeRequest, isNotNull);
      expect(state.activeRequest!.status, equals(ReleaseStatus.cooldown));
      expect(state.remainingTime, equals(const Duration(seconds: 10)));

      // Advance clock by 4 seconds
      getSystemTime = () => initialTime.add(const Duration(seconds: 4));
      async.elapse(const Duration(seconds: 4));

      state = container.read(releaseControllerProvider);
      expect(state.remainingTime, equals(const Duration(seconds: 6)));
    });
  });

  test('Completes release when time elapses and triggers platform update', () {
    fakeAsync((async) {
      createContainer();
      
      final controller = container.read(releaseControllerProvider.notifier);
      final initialTime = DateTime.utc(2026, 6, 22, 12, 0, 0);
      getSystemTime = () => initialTime;

      controller.initiateRelease(durationSeconds: 5);
      async.flushMicrotasks();

      expect(mockPlatformService.isAuthorized, isFalse);

      // Advance clock by 5 seconds
      getSystemTime = () => initialTime.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));

      final state = container.read(releaseControllerProvider);
      expect(state.activeRequest!.status, equals(ReleaseStatus.completed));
      expect(state.remainingTime, equals(Duration.zero));
      expect(mockPlatformService.isAuthorized, isTrue);
    });
  });

  test('Cancelling a release sets status to canceled and deauthorizes platform', () {
    fakeAsync((async) {
      createContainer();
      
      final controller = container.read(releaseControllerProvider.notifier);
      final initialTime = DateTime.utc(2026, 6, 22, 12, 0, 0);
      getSystemTime = () => initialTime;

      controller.initiateRelease(durationSeconds: 10);
      async.flushMicrotasks();

      controller.cancelRelease();
      async.flushMicrotasks();

      final state = container.read(releaseControllerProvider);
      expect(state.activeRequest, isNull);
      expect(state.remainingTime, isNull);
      expect(mockPlatformService.isAuthorized, isFalse);
      expect(mockRepository.history.first.status, equals(ReleaseStatus.canceled));
    });
  });

  test('Clock manipulation or skew blocks transition and sets error', () {
    fakeAsync((async) {
      createContainer();
      
      final controller = container.read(releaseControllerProvider.notifier);
      final initialTime = DateTime.utc(2026, 6, 22, 12, 0, 0);
      getSystemTime = () => initialTime;

      controller.initiateRelease(durationSeconds: 5);
      async.flushMicrotasks();

      // Configure time verification service to throw clock drift exception
      mockTimeService.shouldThrow = true;
      mockTimeService.toThrow = TimeDriftException('Clock skew detected.');

      // Elapse time
      getSystemTime = () => initialTime.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));

      final state = container.read(releaseControllerProvider);
      expect(state.errorMessage, contains('Clock skew detected.'));
      expect(state.activeRequest!.status, equals(ReleaseStatus.cooldown));
      expect(mockPlatformService.isAuthorized, isFalse);
    });
  });

  test('Cooldown completion transitions to pending_approval when partner is linked', () {
    fakeAsync((async) {
      createContainer(
        partnership: const Partnership(
          partnerEmail: 'partner@example.com',
          status: PartnershipStatus.active,
        ),
      );
      
      final controller = container.read(releaseControllerProvider.notifier);
      final initialTime = DateTime.utc(2026, 6, 22, 12, 0, 0);
      getSystemTime = () => initialTime;

      controller.initiateRelease(durationSeconds: 5);
      async.flushMicrotasks();

      // Elapse time
      getSystemTime = () => initialTime.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));

      final state = container.read(releaseControllerProvider);
      expect(state.activeRequest!.status, equals(ReleaseStatus.pending_approval));
      expect(state.remainingTime, equals(Duration.zero));
      expect(mockPlatformService.isAuthorized, isFalse);
    });
  });
}
