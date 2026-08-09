import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/keyword_registry.dart';
import '../domain/keyword_scan_state.dart';

/// Riverpod provider that manages the runtime state of the keyword scanning engine.
///
/// State is ephemeral (memory-only). No scanned text or detection results
/// are persisted to disk or any external service.
final keywordScanProvider =
    NotifierProvider<KeywordScanNotifier, KeywordScanState>(
  KeywordScanNotifier.new,
);

class KeywordScanNotifier extends Notifier<KeywordScanState> {
  @override
  KeywordScanState build() => KeywordScanState.initial();

  /// Processes a pre-matched content scan result received from the native layer.
  ///
  /// The native layer performs all keyword matching and sends only the
  /// structured result — never the raw scanned text — across the bridge.
  ///
  /// [packageName] The package that was scanned.
  /// [detected] Whether any restricted keyword was found.
  /// [matched] The list of keywords that matched.
  /// [timestamp] Unix epoch milliseconds of when the scan completed.
  void processScanResult({
    required String packageName,
    required bool detected,
    required List<String> matched,
    required int timestamp,
  }) {
    state = state.copyWith(
      scannedTextAvailable: true,
      restrictedContentDetected: detected,
      matchedKeywords: matched,
      lastScanTimestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  /// Resets the scan state back to its initial value.
  ///
  /// Called when the user navigates away from a high-risk application, so
  /// stale detection results do not bleed across app sessions.
  void resetState() {
    state = KeywordScanState.initial();
  }
}

// ---------------------------------------------------------------------------
// Convenience selector providers
// ---------------------------------------------------------------------------

/// True if a scan has been completed and results are available.
final scannedTextAvailableProvider = Provider<bool>((ref) {
  return ref.watch(keywordScanProvider).scannedTextAvailable;
});

/// True if restricted content was detected in the most recent scan.
final restrictedContentDetectedProvider = Provider<bool>((ref) {
  return ref.watch(keywordScanProvider).restrictedContentDetected;
});

/// The list of matched keywords from the most recent scan.
/// Empty if no restricted content was detected.
final matchedKeywordsProvider = Provider<List<String>>((ref) {
  return ref.watch(keywordScanProvider).matchedKeywords;
});

/// Timestamp of the most recent completed scan. Null before the first scan.
final lastScanTimestampProvider = Provider<DateTime?>((ref) {
  return ref.watch(keywordScanProvider).lastScanTimestamp;
});

/// Exposes the keyword registry so the native initialization layer can read
/// the list and push it to the Kotlin side without a hard dependency on
/// keyword_registry.dart from outside this feature.
const List<String> exportedKeywordRegistry = keywordRegistry;
