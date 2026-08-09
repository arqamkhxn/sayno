class CuratedContentItem {
  final String id;
  final String title;
  final String sourceId;
  final String provider;
  final int durationSeconds;
  final List<String> identityTags;

  const CuratedContentItem({
    required this.id,
    required this.title,
    required this.sourceId,
    required this.provider,
    required this.durationSeconds,
    required this.identityTags,
  });

  factory CuratedContentItem.fromJson(Map<String, dynamic> json) {
    return CuratedContentItem(
      id: json['id'] as String,
      title: json['title'] as String,
      sourceId: json['source_id'] as String,
      provider: json['provider'] as String,
      durationSeconds: json['duration_seconds'] as int,
      identityTags: (json['identity_tags'] as List<dynamic>).cast<String>(),
    );
  }
}
