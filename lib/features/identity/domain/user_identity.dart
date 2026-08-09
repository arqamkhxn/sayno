import 'identity_profile.dart';

class UserIdentity {
  final IdentityProfile profile;
  final int priority;
  final List<String> selectedGoals;

  const UserIdentity({
    required this.profile,
    required this.priority,
    required this.selectedGoals,
  });

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      profile: IdentityProfile.fromJson(json['profile'] as Map<String, dynamic>),
      priority: json['priority'] as int,
      selectedGoals: (json['selectedGoals'] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'priority': priority,
      'selectedGoals': selectedGoals,
    };
  }

  UserIdentity copyWith({
    IdentityProfile? profile,
    int? priority,
    List<String>? selectedGoals,
  }) {
    return UserIdentity(
      profile: profile ?? this.profile,
      priority: priority ?? this.priority,
      selectedGoals: selectedGoals ?? this.selectedGoals,
    );
  }
}
