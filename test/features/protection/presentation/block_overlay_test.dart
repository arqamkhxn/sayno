import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/block_overlay_controller.dart';
import 'package:sayno/features/protection/application/app_detection_controller.dart';
import 'package:sayno/features/protection/domain/block_reason.dart';
import 'package:sayno/features/protection/presentation/block_overlay.dart';
import 'package:sayno/features/contract/application/contract_controller.dart';
import 'package:sayno/features/contract/domain/contract.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';
import 'package:sayno/shared/widgets/sayno_button.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  group('BlockOverlay Widget Tests', () {
    Widget buildTestWidget({List<Override>? overrides}) {
      return ProviderScope(
        overrides: overrides ?? [
          activeContractProvider.overrideWith(() => FakeActiveContractNotifier(null)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Stack(
                children: [
                  Text('Underneath Content'),
                  Positioned.fill(
                    child: BlockOverlay(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Does not render when isBlockOverlayVisible is false', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Underneath Content'), findsOneWidget);
      expect(find.text('Access Blocked'), findsNothing);
      expect(find.text('Limit Reached'), findsNothing);
      expect(find.byType(SayNOButton), findsNothing);
    });

    testWidgets('Renders Restricted Content block state correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Show overlay with restrictedContent reason
      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.restrictedContent);

      await tester.pumpAndSettle();

      expect(find.text('Access Blocked'), findsOneWidget);
      expect(find.text('This content conflicts with your commitment.'), findsOneWidget);
      expect(find.byType(SayNOButton), findsNWidgets(2));
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Renders Daily Limit Reached block state correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Show overlay with dailyLimitReached reason
      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);

      await tester.pumpAndSettle();

      expect(find.text('Limit Reached'), findsOneWidget);
      expect(find.text('You have reached your daily limit for this application.'), findsOneWidget);
      expect(find.byType(SayNOButton), findsNWidgets(2));
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Pressing Go Back hides the overlay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.restrictedContent);

      await tester.pumpAndSettle();
      expect(find.text('Access Blocked'), findsOneWidget);

      // Tap Go Back
      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();

      expect(find.text('Access Blocked'), findsNothing);
    });

    testWidgets('Pressing Close hides the overlay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);

      await tester.pumpAndSettle();
      expect(find.text('Limit Reached'), findsOneWidget);

      // Tap Close
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Limit Reached'), findsNothing);
    });

    testWidgets('Renders Borrow Minutes button when contract app limit reached and credits remain', (tester) async {
      final contract = Contract(
        id: 1,
        durationDays: 7,
        startTimestampUtc: DateTime.now().toUtc(),
        endTimestampUtc: DateTime.now().toUtc().add(const Duration(days: 7)),
        status: ContractStatus.active,
        apps: [
          const ContractApp(
            id: 1,
            contractId: 1,
            packageName: 'com.instagram.android',
            dailyLimit: Duration(minutes: 40),
            totalCredits: Duration(minutes: 280),
            remainingCredits: Duration(minutes: 280),
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(
        overrides: [
          activeContractProvider.overrideWith(() => FakeActiveContractNotifier(contract)),
          activePackageProvider.overrideWith(() => FakeActivePackageNotifier('com.instagram.android')),
        ],
      ));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);

      await tester.pumpAndSettle();

      expect(find.text('Limit Reached'), findsOneWidget);
      expect(find.text('Borrow Minutes'), findsOneWidget);
    });

    testWidgets('Renders No Credits Remaining when credit pool is depleted', (tester) async {
      final contract = Contract(
        id: 1,
        durationDays: 7,
        startTimestampUtc: DateTime.now().toUtc(),
        endTimestampUtc: DateTime.now().toUtc().add(const Duration(days: 7)),
        status: ContractStatus.active,
        apps: [
          const ContractApp(
            id: 1,
            contractId: 1,
            packageName: 'com.instagram.android',
            dailyLimit: Duration(minutes: 40),
            totalCredits: Duration(minutes: 280),
            remainingCredits: Duration.zero,
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(
        overrides: [
          activeContractProvider.overrideWith(() => FakeActiveContractNotifier(contract)),
          activePackageProvider.overrideWith(() => FakeActivePackageNotifier('com.instagram.android')),
        ],
      ));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);

      await tester.pumpAndSettle();

      expect(find.text('No Credits Remaining'), findsOneWidget);
      expect(find.text('Top-Up Credits (Coming Soon)'), findsOneWidget);
      expect(find.text('Borrow Minutes'), findsNothing);
    });

    testWidgets('Borrow Minutes button opens dialog, shows warning details and performs borrow on confirm', (tester) async {
      final contract = Contract(
        id: 1,
        durationDays: 7,
        startTimestampUtc: DateTime.now().toUtc(),
        endTimestampUtc: DateTime.now().toUtc().add(const Duration(days: 7)),
        status: ContractStatus.active,
        apps: [
          const ContractApp(
            id: 1,
            contractId: 1,
            packageName: 'com.instagram.android',
            dailyLimit: Duration(minutes: 40),
            totalCredits: Duration(minutes: 280),
            remainingCredits: Duration(minutes: 280),
          ),
        ],
      );

      final fakeNotifier = FakeActiveContractNotifier(contract);

      await tester.pumpWidget(buildTestWidget(
        overrides: [
          activeContractProvider.overrideWith(() => fakeNotifier),
          activePackageProvider.overrideWith(() => FakeActivePackageNotifier('com.instagram.android')),
        ],
      ));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Underneath Content')));
      container
          .read(blockOverlayProvider.notifier)
          .showOverlay(BlockReason.dailyLimitReached);

      await tester.pumpAndSettle();

      // Tap Borrow Minutes
      await tester.tap(find.text('Borrow Minutes'));
      await tester.pumpAndSettle();

      // Dialog should be shown
      expect(find.text('Warning: Violation'), findsOneWidget);
      expect(find.text('Reset streak to 0 (Current: 0 days)'), findsOneWidget);
      expect(find.text('Mark today as a Failed Day (Red Day)'), findsOneWidget);
      expect(find.text('Deduct minutes from pool (Remaining: 280m)'), findsOneWidget);

      final borrowButtonFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Borrow'),
      );
      expect(borrowButtonFinder, findsOneWidget);

      // Tap Borrow inside dialog
      await tester.tap(borrowButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Limit Reached'), findsNothing);
      expect(fakeNotifier.borrowedPackage, 'com.instagram.android');
      expect(fakeNotifier.borrowedAmount?.inMinutes, 15);
    });
  });
}

class FakeActiveContractNotifier extends ActiveContractNotifier {
  final Contract? _contract;
  String? borrowedPackage;
  Duration? borrowedAmount;

  FakeActiveContractNotifier(this._contract);

  @override
  Future<Contract?> build() async => _contract;

  @override
  Future<void> borrowMinutes(String packageName, Duration amount) async {
    borrowedPackage = packageName;
    borrowedAmount = amount;
  }
}

class FakeActivePackageNotifier extends ActivePackageNotifier {
  final String? _initialPackage;
  FakeActivePackageNotifier(this._initialPackage);

  @override
  String? build() => _initialPackage;
}
