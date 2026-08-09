import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayno/features/protection/application/keyword_controller.dart';
import 'package:sayno/features/protection/domain/keyword_registry.dart';
import 'package:sayno/features/protection/domain/keyword_scan_state.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('KeywordScanState initial state', () {
    test('starts as initial (no scan run)', () {
      final state = container.read(keywordScanProvider);
      expect(state.scannedTextAvailable, isFalse);
      expect(state.restrictedContentDetected, isFalse);
      expect(state.matchedKeywords, isEmpty);
      expect(state.lastScanTimestamp, isNull);
    });
  });

  group('processScanResult — restricted content detected', () {
    test('updates state when native side reports a match', () {
      final notifier = container.read(keywordScanProvider.notifier);
      final ts = DateTime.now().millisecondsSinceEpoch;

      notifier.processScanResult(
        packageName: 'com.android.chrome',
        detected: true,
        matched: ['porn', 'xxx'],
        timestamp: ts,
      );

      final state = container.read(keywordScanProvider);
      expect(state.scannedTextAvailable, isTrue);
      expect(state.restrictedContentDetected, isTrue);
      expect(state.matchedKeywords, containsAll(['porn', 'xxx']));
      expect(state.lastScanTimestamp,
          equals(DateTime.fromMillisecondsSinceEpoch(ts)));
    });
  });

  group('processScanResult — clean content', () {
    test('updates state but reports no detection when no keywords match', () {
      final notifier = container.read(keywordScanProvider.notifier);
      final ts = DateTime.now().millisecondsSinceEpoch;

      notifier.processScanResult(
        packageName: 'com.android.chrome',
        detected: false,
        matched: [],
        timestamp: ts,
      );

      final state = container.read(keywordScanProvider);
      expect(state.scannedTextAvailable, isTrue);
      expect(state.restrictedContentDetected, isFalse);
      expect(state.matchedKeywords, isEmpty);
    });
  });

  group('resetState', () {
    test('clears all state back to initial after a match', () {
      final notifier = container.read(keywordScanProvider.notifier);

      notifier.processScanResult(
        packageName: 'com.android.chrome',
        detected: true,
        matched: ['nsfw'],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Confirm we have dirty state
      expect(container.read(keywordScanProvider).restrictedContentDetected, isTrue);

      notifier.resetState();

      final state = container.read(keywordScanProvider);
      expect(state, equals(KeywordScanState.initial()));
    });

    test('resetState is idempotent when already initial', () {
      final notifier = container.read(keywordScanProvider.notifier);
      notifier.resetState();
      final state = container.read(keywordScanProvider);
      expect(state, equals(KeywordScanState.initial()));
    });
  });

  group('Selector providers', () {
    test('scannedTextAvailableProvider reflects scan completion', () {
      expect(container.read(scannedTextAvailableProvider), isFalse);

      container.read(keywordScanProvider.notifier).processScanResult(
            packageName: 'com.android.chrome',
            detected: false,
            matched: [],
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

      expect(container.read(scannedTextAvailableProvider), isTrue);
    });

    test('restrictedContentDetectedProvider reflects detection', () {
      expect(container.read(restrictedContentDetectedProvider), isFalse);

      container.read(keywordScanProvider.notifier).processScanResult(
            packageName: 'com.android.chrome',
            detected: true,
            matched: ['xxx'],
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

      expect(container.read(restrictedContentDetectedProvider), isTrue);
    });

    test('matchedKeywordsProvider returns the matched list', () {
      container.read(keywordScanProvider.notifier).processScanResult(
            packageName: 'com.android.chrome',
            detected: true,
            matched: ['porn', 'hentai'],
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

      final matched = container.read(matchedKeywordsProvider);
      expect(matched, containsAll(['porn', 'hentai']));
      expect(matched.length, 2);
    });

    test('lastScanTimestampProvider returns the scan timestamp', () {
      final ts = DateTime.now().millisecondsSinceEpoch;

      container.read(keywordScanProvider.notifier).processScanResult(
            packageName: 'com.android.chrome',
            detected: false,
            matched: [],
            timestamp: ts,
          );

      expect(
        container.read(lastScanTimestampProvider),
        equals(DateTime.fromMillisecondsSinceEpoch(ts)),
      );
    });

    test('all selectors reset together after resetState()', () {
      container.read(keywordScanProvider.notifier).processScanResult(
            packageName: 'com.android.chrome',
            detected: true,
            matched: ['nsfw'],
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

      container.read(keywordScanProvider.notifier).resetState();

      expect(container.read(scannedTextAvailableProvider), isFalse);
      expect(container.read(restrictedContentDetectedProvider), isFalse);
      expect(container.read(matchedKeywordsProvider), isEmpty);
      expect(container.read(lastScanTimestampProvider), isNull);
    });
  });

  group('Keyword registry integrity', () {
    test('keywordRegistry is non-empty', () {
      expect(keywordRegistry, isNotEmpty);
    });

    test('keywordRegistry contains expected baseline keywords', () {
      const baseline = ['porn', 'xxx', 'nsfw', 'hentai', 'nude'];
      for (final keyword in baseline) {
        expect(keywordRegistry, contains(keyword),
            reason: 'Expected "$keyword" in keywordRegistry');
      }
    });

    test('all keywords are lowercase and non-blank', () {
      for (final keyword in keywordRegistry) {
        expect(keyword.trim(), isNotEmpty,
            reason: 'Registry contains a blank keyword');
        expect(keyword, equals(keyword.toLowerCase()),
            reason: '"$keyword" should be lowercase in the registry');
      }
    });

    test('exportedKeywordRegistry matches keywordRegistry', () {
      expect(exportedKeywordRegistry, equals(keywordRegistry));
    });
  });

  group('KeywordScanState equality and copyWith', () {
    test('two initial states are equal', () {
      expect(KeywordScanState.initial(), equals(KeywordScanState.initial()));
    });

    test('copyWith produces distinct instances with updated fields', () {
      final base = KeywordScanState.initial();
      final updated = base.copyWith(
        restrictedContentDetected: true,
        matchedKeywords: ['porn'],
      );

      expect(updated.restrictedContentDetected, isTrue);
      expect(updated.matchedKeywords, contains('porn'));
      // Unchanged fields
      expect(updated.scannedTextAvailable, isFalse);
      expect(updated.lastScanTimestamp, isNull);
    });
  });
}
