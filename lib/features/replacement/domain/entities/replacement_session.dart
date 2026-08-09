class ReplacementSession {
  final String id;
  final String videoId;
  final int durationSeconds;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ReplacementSession({
    required this.id,
    required this.videoId,
    required this.durationSeconds,
    required this.startedAt,
    this.completedAt,
  });

  ReplacementSession copyWith({
    String? id,
    String? videoId,
    int? durationSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ReplacementSession(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
