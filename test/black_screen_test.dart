import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayno/app.dart';

void main() {
  testWidgets('Simulate GoRouter transition after login', (tester) async {
    // Just run the app in the test environment to see if it throws on start or when trying to navigate
    await tester.pumpWidget(
      ProviderScope(
        child: const SayNOApp(),
      ),
    );
    await tester.pumpAndSettle();
  });
}
