import '../entities/curated_content_item.dart';

abstract class CatalogRepository {
  Future<List<CuratedContentItem>> getCatalogForIdentity(String identityId);
  Future<void> refreshCatalog();
}
