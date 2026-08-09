class ContentItem {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String provider;
  final String providerId;
  final Duration duration;
  final String difficulty;
  final String estimatedTime;
  final String collectionName;
  final List<String> tags;

  const ContentItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.provider,
    required this.providerId,
    required this.duration,
    required this.difficulty,
    required this.estimatedTime,
    required this.collectionName,
    required this.tags,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      provider: json['provider'] as String,
      providerId: json['providerId'] as String,
      duration: Duration(seconds: json['durationSeconds'] as int),
      difficulty: json['difficulty'] as String,
      estimatedTime: json['estimatedTime'] as String,
      collectionName: json['collectionName'] as String,
      tags: (json['tags'] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'provider': provider,
      'providerId': providerId,
      'durationSeconds': duration.inSeconds,
      'difficulty': difficulty,
      'estimatedTime': estimatedTime,
      'collectionName': collectionName,
      'tags': tags,
    };
  }
}
