import '../entities/user_identity.dart';

abstract class IdentityRepository {
  Future<void> saveActiveIdentityId(String identityId);
  Future<String?> getActiveIdentityId();
  Future<List<UserIdentity>> getAvailableIdentities();
}
