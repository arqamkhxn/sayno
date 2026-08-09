import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/contract/domain/contract_app.dart';

void main() {
  group('ContractApp Domain Model Tests', () {
    test('Default constructor sets restrictionMode to time_limit', () {
      const app = ContractApp(
        packageName: 'com.instagram.android',
        dailyLimit: Duration(minutes: 30),
        totalCredits: Duration(hours: 5),
        remainingCredits: Duration(hours: 5),
      );

      expect(app.restrictionMode, RestrictionMode.time_limit);
    });

    test('parseMode maps exact enum string values correctly', () {
      expect(ContractApp.parseMode('utility'), RestrictionMode.utility);
      expect(ContractApp.parseMode('time_limit'), RestrictionMode.time_limit);
      expect(ContractApp.parseMode('focus'), RestrictionMode.focus);
      expect(ContractApp.parseMode('monk'), RestrictionMode.monk);
    });

    test('parseMode defaults/falls back to time_limit on invalid/null inputs', () {
      expect(ContractApp.parseMode(null), RestrictionMode.time_limit);
      expect(ContractApp.parseMode(''), RestrictionMode.time_limit);
      expect(ContractApp.parseMode('invalid_mode_name'), RestrictionMode.time_limit);
    });

    test('copyWith copies all fields and overrides specified ones', () {
      const app = ContractApp(
        packageName: 'com.instagram.android',
        dailyLimit: Duration(minutes: 30),
        totalCredits: Duration(hours: 5),
        remainingCredits: Duration(hours: 5),
        restrictionMode: RestrictionMode.focus,
      );

      final updated = app.copyWith(
        restrictionMode: RestrictionMode.monk,
        remainingCredits: Duration(hours: 4),
      );

      expect(updated.packageName, app.packageName);
      expect(updated.dailyLimit, app.dailyLimit);
      expect(updated.totalCredits, app.totalCredits);
      expect(updated.remainingCredits, const Duration(hours: 4));
      expect(updated.restrictionMode, RestrictionMode.monk);
    });
  });
}
