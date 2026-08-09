import '../entities/curated_content_item.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/identity_repository.dart';

class GetCuratedTopicsUseCase {
  final CatalogRepository _catalogRepository;
  final IdentityRepository _identityRepository;

  GetCuratedTopicsUseCase(this._catalogRepository, this._identityRepository);

  Future<List<CuratedContentItem>> execute() async {
    final identityId = await _identityRepository.getActiveIdentityId();
    if (identityId == null) {
      return [];
    }
    return _catalogRepository.getCatalogForIdentity(identityId);
  }
}
