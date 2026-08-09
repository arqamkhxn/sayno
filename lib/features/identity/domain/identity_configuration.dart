import 'user_identity.dart';

class IdentityConfiguration {
  final String id;
  final DateTime timestamp;
  final bool isActive;
  final List<UserIdentity> identities;
  
  const IdentityConfiguration({
    required this.id,
    required this.timestamp,
    required this.isActive,
    required this.identities,
  });

  bool get isValid => identities.isNotEmpty && identities.length <= 4;

  factory IdentityConfiguration.fromJson(Map<String, dynamic> json) {
    final identitiesList = json['identities'] as List;
    return IdentityConfiguration(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isActive: json['isActive'] as bool,
      identities: identitiesList
          .map((i) => UserIdentity.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'isActive': isActive,
      'identities': identities.map((i) => i.toJson()).toList(),
    };
  }
}
