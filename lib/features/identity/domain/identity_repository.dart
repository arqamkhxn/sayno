import 'identity_configuration.dart';

abstract class IdentityRepository {
  Future<IdentityConfiguration?> getActiveConfiguration();
  Future<void> saveConfiguration(IdentityConfiguration config);
}
