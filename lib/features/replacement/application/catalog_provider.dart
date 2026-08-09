import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/curated_content_item.dart';
import '../domain/repositories/catalog_repository.dart';
import '../data/repositories/catalog_repository_impl.dart';
import '../data/providers/remote_catalog_provider.dart';
import '../data/providers/firebase_catalog_provider.dart';
import 'identity_provider.dart';

final remoteCatalogProviderProvider = Provider<RemoteCatalogProvider>((ref) {
  // Swappable backend infrastructure
  return FirebaseCatalogProvider();
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final remoteProvider = ref.watch(remoteCatalogProviderProvider);
  return CatalogRepositoryImpl(remoteProvider);
});

final curatedTopicsProvider = FutureProvider<List<CuratedContentItem>>((ref) async {
  final identity = await ref.watch(activeIdentityProvider.future);
  if (identity == null) return [];
  
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.getCatalogForIdentity(identity.id);
});
