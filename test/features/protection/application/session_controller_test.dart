import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/app_detection_controller.dart';
import 'package:sayno/features/protection/application/protection_controller.dart';
import 'package:sayno/features/protection/application/session_controller.dart';
import 'package:sayno/features/protection/data/protection_platform_service.dart';
import 'package:sayno/features/protection/data/session_repository.dart';
import 'package:sayno/features/protection/domain/app_session.dart';

class TestActivePackageNotifier extends ActivePackageNotifier {
  TestActivePackageNotifier({String? initialState}) : _initialState = initialState;

  final String? _initialState;

  @override
  String? build() {
    return _initialState;
  }

  void setPackage(String? package) {
    state = package;
  }
}

class MockSessionRepository implements SessionRepository {
  final List<AppSession> savedSessions = [];
  Duration mockTodayTotalUsage = Duration.zero;
  Map<String, Duration> mockTodayPerAppUsage = {};

  @override
  Future<void> saveSession(AppSession session) async {
    savedSessions.add(session);
    mockTodayTotalUsage += session.duration;
    final package = session.packageName;
    mockTodayPerAppUsage[package] = (mockTodayPerAppUsage[package] ?? Duration.zero) + session.duration;
  }

  @override
  Future<Duration> getTodayTotalUsage() async {
    return mockTodayTotalUsage;
  }

  @override
  Future<Map<String, Duration>> getTodayPerAppUsage() async {
    return mockTodayPerAppUsage;
  }
}

class StubProtectionPlatformService implements ProtectionPlatformService {
  @override
  Future<List<Map<String, String>>> getInstalledApps() async => [];

  StubProtectionPlatformService(this.repository);
  final MockSessionRepository repository;

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
  void setAccessibilityEventListener(void Function(Map<String, dynamic>) callback) {}
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
  Future<bool> updateVerifiedTime(int epochSeconds) async => true;
  @override
  Future<bool> updateActiveContractStatus(bool isActive) async => true;
  @override
  Future<bool> updateReleaseAuthorization(bool isAuthorized) async => true;

  @override
  Future<int> getUsage(String packageName) async {
    return repository.mockTodayPerAppUsage[packageName]?.inSeconds ?? 0;
  }

  @override
  Future<int> getUsageForPackageOnDateUtc(String packageName, String dateUtc) async {
    return repository.mockTodayPerAppUsage[packageName]?.inSeconds ?? 0;
  }

  @override
  Future<Map<String, int>> getAllUsage() async {
    return repository.mockTodayPerAppUsage.map((key, val) => MapEntry(key, val.inSeconds));
  }
}

ProviderContainer createContainer({
  required TestActivePackageNotifier activePackageNotifier,
  required SessionRepository sessionRepository,
  bool isScreenOn = true,
  bool isDeviceUnlocked = true,
  bool isProtectionAvailable = true,
}) {
  return ProviderContainer(
    overrides: [
      activePackageProvider.overrideWith(() => activePackageNotifier),
      sessionRepositoryProvider.overrideWithValue(sessionRepository),
      protectionPlatformServiceProvider.overrideWithValue(
        StubProtectionPlatformService(sessionRepository as MockSessionRepository),
      ),
      isScreenOnProvider.overrideWith((ref) => isScreenOn),
      isDeviceUnlockedProvider.overrideWith((ref) => isDeviceUnlocked),
      isProtectionAvailableProvider.overrideWith((ref) => isProtectionAvailable),
    ],
  );
}

void main() {
  setUp(() {
    getSystemTime = () => clock.now();
  });

  tearDown(() {
    getSystemTime = () => DateTime.now();
  });

  group('Session Tracking & Persistence Tests', () {
    test('Initial state when no app is active', () {
      final testNotifier = TestActivePackageNotifier();
      final mockRepository = MockSessionRepository();
      
      final container = createContainer(
        activePackageNotifier: testNotifier,
        sessionRepository: mockRepository,
      );
      addTearDown(container.dispose);

      expect(container.read(activeSessionProvider), isNull);
      expect(container.read(sessionCountProvider), 0);
      expect(container.read(todayTotalUsageProvider), Duration.zero);
    });

    test('Session starts, increments count, and tracks duration correctly', () {
      fakeAsync((async) {
        final testNotifier = TestActivePackageNotifier();
        final mockRepository = MockSessionRepository();
        
        final container = createContainer(
          activePackageNotifier: testNotifier,
          sessionRepository: mockRepository,
        );
        addTearDown(container.dispose);

        // Keep activeSessionProvider alive
        container.listen(activeSessionProvider, (prev, next) {});
        container.read(sessionCountProvider);

        testNotifier.setPackage('com.google.android.youtube');

        final session = container.read(activeSessionProvider);
        expect(session, isNotNull);
        expect(session!.packageName, 'com.google.android.youtube');
        expect(session.appName, 'YouTube');
        expect(session.duration, Duration.zero);
        expect(session.isActive, isTrue);
        expect(container.read(sessionCountProvider), 1);

        async.elapse(const Duration(seconds: 5));

        final updatedSession = container.read(activeSessionProvider);
        expect(updatedSession!.duration.inSeconds, 5);
        expect(updatedSession.isActive, isTrue);
      });
    });

    test('Saving completed session updates persistedTodayUsageProvider and todayTotalUsageProvider', () {
      fakeAsync((async) {
        final testNotifier = TestActivePackageNotifier();
        final mockRepository = MockSessionRepository();
        
        final container = createContainer(
          activePackageNotifier: testNotifier,
          sessionRepository: mockRepository,
        );
        addTearDown(container.dispose);

        // Keep providers alive to trigger immediate futures
        container.listen(activeSessionProvider, (prev, next) {});
        container.listen(persistedTodayUsageProvider, (prev, next) {});

        expect(container.read(todayTotalUsageProvider), Duration.zero);

        // Start session
        testNotifier.setPackage('com.google.android.youtube');
        
        async.elapse(const Duration(seconds: 5));
        
        expect(container.read(todayTotalUsageProvider).inSeconds, 5);

        // End session (triggers saving on dispose)
        testNotifier.setPackage(null);
        
        // Let async futures execute
        async.elapse(const Duration(milliseconds: 100));

        expect(mockRepository.savedSessions.length, 1);
        expect(mockRepository.savedSessions.first.duration.inSeconds, 5);

        final persistedUsageAsync = container.read(persistedTodayUsageProvider);
        expect(persistedUsageAsync.value, const Duration(seconds: 5));
        expect(container.read(todayTotalUsageProvider).inSeconds, 5);
      });
    });

    test('Per-app totals are correctly tracked and combined with active session', () {
      fakeAsync((async) {
        final testNotifier = TestActivePackageNotifier();
        final mockRepository = MockSessionRepository();
        
        final container = createContainer(
          activePackageNotifier: testNotifier,
          sessionRepository: mockRepository,
        );
        addTearDown(container.dispose);

        // Keep providers alive
        container.listen(activeSessionProvider, (prev, next) {});
        container.listen(persistedTodayAppUsageProvider, (prev, next) {});
        container.read(todayAppUsageProvider);

        // Session 1: YouTube for 10 seconds
        testNotifier.setPackage('com.google.android.youtube');
        async.elapse(const Duration(seconds: 10));
        testNotifier.setPackage(null);
        async.elapse(const Duration(milliseconds: 100));

        // Session 2: Instagram for 15 seconds
        testNotifier.setPackage('com.instagram.android');
        async.elapse(const Duration(seconds: 15));
        testNotifier.setPackage(null);
        async.elapse(const Duration(milliseconds: 100));

        // Session 3: YouTube again (active) for 5 seconds
        testNotifier.setPackage('com.google.android.youtube');
        async.elapse(const Duration(seconds: 5));

        final appUsage = container.read(todayAppUsageProvider);
        expect(appUsage['com.google.android.youtube']?.inSeconds, 15);
        expect(appUsage['com.instagram.android']?.inSeconds, 15);
      });
    });

    test('Initial active package on startup is captured correctly', () {
      final testNotifier = TestActivePackageNotifier(initialState: 'com.google.android.youtube');
      final mockRepository = MockSessionRepository();
      
      final container = createContainer(
        activePackageNotifier: testNotifier,
        sessionRepository: mockRepository,
      );
      addTearDown(container.dispose);

      expect(container.read(sessionCountProvider), 1);
      expect(container.read(activeSessionProvider)!.packageName, 'com.google.android.youtube');
    });

    test('Session pauses when screen turns off, saves duration, and resumes when screen turns on', () {
      fakeAsync((async) {
        final testNotifier = TestActivePackageNotifier();
        final mockRepository = MockSessionRepository();
        
        final container = createContainer(
          activePackageNotifier: testNotifier,
          sessionRepository: mockRepository,
        );
        addTearDown(container.dispose);

        // Keep providers alive
        container.listen(activeSessionProvider, (prev, next) {});
        container.listen(persistedTodayUsageProvider, (prev, next) {});

        // Start session
        testNotifier.setPackage('com.google.android.youtube');
        async.elapse(const Duration(seconds: 5));
        
        expect(container.read(activeSessionProvider), isNotNull);
        expect(container.read(todayTotalUsageProvider).inSeconds, 5);

        // Turn off screen
        container.read(isScreenOnProvider.notifier).state = false;
        async.elapse(const Duration(milliseconds: 100));

        // Active session should be null, and completed session should be saved
        expect(container.read(activeSessionProvider), isNull);
        expect(mockRepository.savedSessions.length, 1);
        expect(mockRepository.savedSessions.first.duration.inSeconds, 5);
        expect(container.read(todayTotalUsageProvider).inSeconds, 5);

        // Turn screen back on
        container.read(isScreenOnProvider.notifier).state = true;
        async.elapse(const Duration(seconds: 3));

        // Active session should resume
        expect(container.read(activeSessionProvider), isNotNull);
        expect(container.read(activeSessionProvider)!.duration.inSeconds, 3);
        expect(container.read(todayTotalUsageProvider).inSeconds, 8);
      });
    });

    test('Session pauses when device locks and does not resume when screen turns on until unlocked', () {
      fakeAsync((async) {
        final testNotifier = TestActivePackageNotifier();
        final mockRepository = MockSessionRepository();
        
        final container = createContainer(
          activePackageNotifier: testNotifier,
          sessionRepository: mockRepository,
        );
        addTearDown(container.dispose);

        // Keep providers alive
        container.listen(activeSessionProvider, (prev, next) {});
        container.listen(persistedTodayUsageProvider, (prev, next) {});

        // Start session
        testNotifier.setPackage('com.google.android.youtube');
        async.elapse(const Duration(seconds: 5));

        // Lock device
        container.read(isDeviceUnlockedProvider.notifier).state = false;
        async.elapse(const Duration(milliseconds: 100));

        expect(container.read(activeSessionProvider), isNull);
        expect(mockRepository.savedSessions.length, 1);
        expect(mockRepository.savedSessions.first.duration.inSeconds, 5);

        // Turn screen on but keep device locked
        container.read(isScreenOnProvider.notifier).state = true;
        async.elapse(const Duration(seconds: 5));

        expect(container.read(activeSessionProvider), isNull);

        // Unlock device
        container.read(isDeviceUnlockedProvider.notifier).state = true;
        async.elapse(const Duration(seconds: 4));

        expect(container.read(activeSessionProvider), isNotNull);
        expect(container.read(activeSessionProvider)!.duration.inSeconds, 4);
        expect(container.read(todayTotalUsageProvider).inSeconds, 9);
      });
    });

    test('Session pauses when protection becomes unavailable and resumes when re-enabled', () {
      fakeAsync((async) {
        final testNotifier = TestActivePackageNotifier();
        final mockRepository = MockSessionRepository();
        
        final container = createContainer(
          activePackageNotifier: testNotifier,
          sessionRepository: mockRepository,
        );
        addTearDown(container.dispose);

        // Keep providers alive
        container.listen(activeSessionProvider, (prev, next) {});
        container.listen(persistedTodayUsageProvider, (prev, next) {});

        // Start session
        testNotifier.setPackage('com.google.android.youtube');
        async.elapse(const Duration(seconds: 5));

        // Disable protection
        container.read(isProtectionAvailableProvider.notifier).state = false;
        async.elapse(const Duration(milliseconds: 100));

        expect(container.read(activeSessionProvider), isNull);
        expect(mockRepository.savedSessions.length, 1);
        expect(mockRepository.savedSessions.first.duration.inSeconds, 5);

        // Re-enable protection
        container.read(isProtectionAvailableProvider.notifier).state = true;
        async.elapse(const Duration(seconds: 4));

        expect(container.read(activeSessionProvider), isNotNull);
        expect(container.read(activeSessionProvider)!.duration.inSeconds, 4);
        expect(container.read(todayTotalUsageProvider).inSeconds, 9);
      });
    });
  });
}
