import 'content_item.dart';

enum CollectionType {
  continueLearning,
  curated,
  featured,
  explore,
}

class ContentCollection {
  final String id;
  final String title;
  final String? subtitle;
  final CollectionType type;
  final List<ContentItem> items;

  const ContentCollection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.items,
  });

  factory ContentCollection.fromJson(Map<String, dynamic> json) {
    return ContentCollection(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      type: CollectionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CollectionType.curated,
      ),
      items: (json['items'] as List)
          .map((i) => ContentItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type.name,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
