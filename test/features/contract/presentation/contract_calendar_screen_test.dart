import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/contract/application/contract_controller.dart';
import 'package:sayno/features/contract/domain/contract.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';
import 'package:sayno/features/contract/domain/contract_day_record.dart';
import 'package:sayno/features/contract/presentation/contract_calendar_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeActiveContractNotifier extends ActiveContractNotifier {
  final Contract? _contract;
  FakeActiveContractNotifier(this._contract);

  @override
  Future<Contract?> build() async => _contract;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ContractCalendarScreen Widget Tests', () {
    Widget buildTestWidget({List<Override> overrides = const []}) {
      return ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: ContractCalendarScreen(),
        ),
      );
    }

    testWidgets('Renders active contract calendar grid and details', (tester) async {
      final contract = Contract(
        id: 1,
        durationDays: 7,
        startTimestampUtc: DateTime.utc(2026, 6, 21),
        endTimestampUtc: DateTime.utc(2026, 6, 28),
        status: ContractStatus.active,
        currentStreak: 3,
        longestStreak: 5,
        apps: [
          const ContractApp(
            id: 1,
            contractId: 1,
            packageName: 'com.instagram.android',
            dailyLimit: Duration(minutes: 40),
            totalCredits: Duration(minutes: 280),
            remainingCredits: Duration(minutes: 240),
          ),
        ],
      );

      final records = [
        const ContractDayRecord(
          id: 1,
          contractId: 1,
          dateUtc: '2026-06-21',
          status: ContractDayStatus.green,
        ),
        const ContractDayRecord(
          id: 2,
          contractId: 1,
          dateUtc: '2026-06-22',
          status: ContractDayStatus.red,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        overrides: [
          activeContractProvider.overrideWith(() => FakeActiveContractNotifier(contract)),
          contractCalendarProvider(1).overrideWith((ref) => records),
        ],
      ));

      await tester.pumpAndSettle();

      // Check header title
      expect(find.text('Contract Calendar'), findsOneWidget);

      // Check streak summaries
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Longest Streak'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);

      // Check calendar grid cells
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.text('Day 7'), findsOneWidget);

      // Check app credit pools section
      expect(find.text('App Credit Pools'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('240 / 280 mins'), findsOneWidget);
      expect(find.text('Daily Limit: 40 mins/day'), findsOneWidget);
    });
  });
}
