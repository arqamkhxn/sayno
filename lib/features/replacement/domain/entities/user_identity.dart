class UserIdentity {
  final String id;
  final String label;
  final String description;

  const UserIdentity({
    required this.id,
    required this.label,
    required this.description,
  });

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
    );
  }
}
