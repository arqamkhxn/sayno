import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity_profile.dart';
import '../domain/identity_catalog_provider.dart';
import '../data/local_identity_catalog_provider.dart';

final identityCatalogProviderProvider = Provider<IdentityCatalogProvider>((ref) {
  return LocalIdentityCatalogProvider();
});

final identityCatalogControllerProvider = FutureProvider<List<IdentityProfile>>((ref) {
  final provider = ref.watch(identityCatalogProviderProvider);
  return provider.fetchAvailableIdentities();
});
