/// Represents the runtime state of the keyword scanning engine.
///
/// This model is ephemeral — it lives only in memory and is never persisted
/// to disk, database, or any external service. Scanned text is never stored;
/// only detection results are captured here.
class KeywordScanState {
  /// Whether a scan has been completed and results are available.
  final bool scannedTextAvailable;

  /// Whether restricted content was detected in the last scan.
  final bool restrictedContentDetected;

  /// The list of matched keywords from the last scan. Empty if no match.
  final List<String> matchedKeywords;

  /// Timestamp of the last completed scan. Null before the first scan.
  final DateTime? lastScanTimestamp;

  const KeywordScanState({
    required this.scannedTextAvailable,
    required this.restrictedContentDetected,
    required this.matchedKeywords,
    required this.lastScanTimestamp,
  });

  /// Returns the clean initial state before any scan has run.
  factory KeywordScanState.initial() {
    return const KeywordScanState(
      scannedTextAvailable: false,
      restrictedContentDetected: false,
      matchedKeywords: [],
      lastScanTimestamp: null,
    );
  }

  KeywordScanState copyWith({
    bool? scannedTextAvailable,
    bool? restrictedContentDetected,
    List<String>? matchedKeywords,
    DateTime? lastScanTimestamp,
  }) {
    return KeywordScanState(
      scannedTextAvailable: scannedTextAvailable ?? this.scannedTextAvailable,
      restrictedContentDetected:
          restrictedContentDetected ?? this.restrictedContentDetected,
      matchedKeywords: matchedKeywords ?? this.matchedKeywords,
      lastScanTimestamp: lastScanTimestamp ?? this.lastScanTimestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordScanState &&
          runtimeType == other.runtimeType &&
          scannedTextAvailable == other.scannedTextAvailable &&
          restrictedContentDetected == other.restrictedContentDetected &&
          matchedKeywords == other.matchedKeywords &&
          lastScanTimestamp == other.lastScanTimestamp;

  @override
  int get hashCode =>
      scannedTextAvailable.hashCode ^
      restrictedContentDetected.hashCode ^
      matchedKeywords.hashCode ^
      lastScanTimestamp.hashCode;

  @override
  String toString() => 'KeywordScanState('
      'scannedTextAvailable: $scannedTextAvailable, '
      'restrictedContentDetected: $restrictedContentDetected, '
      'matchedKeywords: $matchedKeywords, '
      'lastScanTimestamp: $lastScanTimestamp'
      ')';
}
