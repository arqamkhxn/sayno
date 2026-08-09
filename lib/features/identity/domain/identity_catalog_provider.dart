import 'identity_profile.dart';

abstract class IdentityCatalogProvider {
  Future<List<IdentityProfile>> fetchAvailableIdentities();
}
