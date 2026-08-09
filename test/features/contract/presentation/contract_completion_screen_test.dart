import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/contract/application/contract_controller.dart';
import 'package:sayno/features/contract/domain/contract.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';
import 'package:sayno/features/contract/domain/contract_day_record.dart';
import 'package:sayno/features/contract/presentation/contract_completion_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeActiveContractNotifier extends ActiveContractNotifier {
  final Contract? _contract;
  ContractStatus? completedWithStatus;

  FakeActiveContractNotifier(this._contract);

  @override
  Future<Contract?> build() async => _contract;

  @override
  Future<void> completeActiveContract(ContractStatus status) async {
    completedWithStatus = status;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ContractCompletionScreen Widget Tests', () {
    Widget buildTestWidget({List<Override> overrides = const []}) {
      return ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: ContractCompletionScreen(),
        ),
      );
    }

    testWidgets('Renders perfect contract completion and clicks complete', (tester) async {
      final contract = Contract(
        id: 1,
        durationDays: 7,
        startTimestampUtc: DateTime.utc(2026, 6, 21),
        endTimestampUtc: DateTime.utc(2026, 6, 28),
        status: ContractStatus.active,
        currentStreak: 7,
        longestStreak: 7,
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

      final records = List.generate(7, (i) {
        return ContractDayRecord(
          id: i + 1,
          contractId: 1,
          dateUtc: '2026-06-${21 + i}',
          status: ContractDayStatus.green,
        );
      });

      final fakeNotifier = FakeActiveContractNotifier(contract);

      await tester.pumpWidget(buildTestWidget(
        overrides: [
          activeContractProvider.overrideWith(() => fakeNotifier),
          contractCalendarProvider(1).overrideWith((ref) => records),
        ],
      ));

      await tester.pumpAndSettle();

      // Check headers
      expect(find.text('Perfect Commitment!'), findsOneWidget);
      expect(find.text('You successfully kept all daily limits for 7 days.'), findsOneWidget);

      // Check metrics
      expect(find.text('Success Rate'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('7 Perfect Days'), findsOneWidget);

      // Check complete button click
      await tester.tap(find.text('Archive & Complete Contract'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.completedWithStatus, ContractStatus.completed);
    });

    testWidgets('Renders failed/imperfect contract completion screen', (tester) async {
      final contract = Contract(
        id: 1,
        durationDays: 7,
        startTimestampUtc: DateTime.utc(2026, 6, 21),
        endTimestampUtc: DateTime.utc(2026, 6, 28),
        status: ContractStatus.active,
        currentStreak: 0,
        longestStreak: 3,
        apps: [
          const ContractApp(
            id: 1,
            contractId: 1,
            packageName: 'com.instagram.android',
            dailyLimit: Duration(minutes: 40),
            totalCredits: Duration(minutes: 280),
            remainingCredits: Duration(minutes: 180),
          ),
        ],
      );

      final records = [
        const ContractDayRecord(id: 1, contractId: 1, dateUtc: '2026-06-21', status: ContractDayStatus.green),
        const ContractDayRecord(id: 2, contractId: 1, dateUtc: '2026-06-22', status: ContractDayStatus.green),
        const ContractDayRecord(id: 3, contractId: 1, dateUtc: '2026-06-23', status: ContractDayStatus.green),
        const ContractDayRecord(id: 4, contractId: 1, dateUtc: '2026-06-24', status: ContractDayStatus.red), // Violation!
        const ContractDayRecord(id: 5, contractId: 1, dateUtc: '2026-06-25', status: ContractDayStatus.green),
        const ContractDayRecord(id: 6, contractId: 1, dateUtc: '2026-06-26', status: ContractDayStatus.green),
        const ContractDayRecord(id: 7, contractId: 1, dateUtc: '2026-06-27', status: ContractDayStatus.green),
      ];

      final fakeNotifier = FakeActiveContractNotifier(contract);

      await tester.pumpWidget(buildTestWidget(
        overrides: [
          activeContractProvider.overrideWith(() => fakeNotifier),
          contractCalendarProvider(1).overrideWith((ref) => records),
        ],
      ));

      await tester.pumpAndSettle();

      // Check imperfect headers
      expect(find.text('Contract Completed'), findsOneWidget);
      expect(find.text('You finished the commitment. Here is your final summary.'), findsOneWidget);

      // Check success rate (6/7 = 86%)
      expect(find.text('86%'), findsOneWidget);
      expect(find.text('6 Perfect Days'), findsOneWidget);
      expect(find.text('1 Violation Days'), findsOneWidget);

      // Check complete button click
      await tester.tap(find.text('Archive & Complete Contract'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.completedWithStatus, ContractStatus.failed);
    });
  });
}
