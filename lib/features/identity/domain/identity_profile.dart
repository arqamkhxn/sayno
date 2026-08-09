class IdentityProfile {
  final String id;
  final String label;
  final String description;
  final List<String> defaultGoals;
  final String? iconName;

  const IdentityProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.defaultGoals,
    this.iconName,
  });

  factory IdentityProfile.fromJson(Map<String, dynamic> json) {
    return IdentityProfile(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      defaultGoals: (json['defaultGoals'] as List).cast<String>(),
      iconName: json['iconName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'defaultGoals': defaultGoals,
      'iconName': iconName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentityProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
