import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/application/identity_controller.dart';
import '../data/content_repository_impl.dart';
import '../data/seed_content_catalog_provider.dart';
import '../data/uce_content_catalog_provider.dart';
import '../domain/content_collection.dart';
import '../domain/content_repository.dart';

/// Provides the [ContentRepository] used by the home feed.
///
/// TSK-5.1.2: Wires [UceContentCatalogProvider] as the primary source,
/// with [SeedContentCatalogProvider] retained as an offline fallback.
///
/// The [UceContentCatalogProvider] calls `GET /v1/feed/{userId}` on the
/// UCE Feed API, authenticated with the current user's Firebase ID token.
/// On any network or auth failure, [SeedContentCatalogProvider] is used
/// automatically — no user-visible error occurs.
///
/// @see UceContentCatalogProvider — Live backend integration
/// @see SeedContentCatalogProvider — Offline fallback
/// @see EIS §11 — Feed API Specification
final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepositoryImpl(
    UceContentCatalogProvider(
      fallback: SeedContentCatalogProvider(),
    ),
  );
});

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, List<ContentCollection>>(
  () => HomeController(),
);

class HomeController extends AsyncNotifier<List<ContentCollection>> {
  @override
  Future<List<ContentCollection>> build() async {
    final activeIdentity = ref.watch(identityControllerProvider).value;
    final repo = ref.watch(contentRepositoryProvider);

    return repo.getHomeCollections(activeIdentity);
  }
}
