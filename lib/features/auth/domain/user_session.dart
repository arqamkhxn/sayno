class UserSession {
  final String uid;
  final String? email;
  final String? displayName;

  const UserSession({
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSession &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName;

  @override
  int get hashCode => uid.hashCode ^ email.hashCode ^ displayName.hashCode;
}
