import '../../identity/domain/identity_configuration.dart';
import '../domain/content_catalog_provider.dart';
import '../domain/content_collection.dart';
import '../domain/content_repository.dart';

class ContentRepositoryImpl implements ContentRepository {
  final ContentCatalogProvider _catalogProvider;

  ContentRepositoryImpl(this._catalogProvider);

  @override
  Future<List<ContentCollection>> getHomeCollections(IdentityConfiguration? activeIdentity) async {
    // In the future, this repository might cache these collections 
    // in sqflite or manage offline synchronization.
    return _catalogProvider.fetchHomeCollections(activeIdentity);
  }
}
