import '../../identity/domain/identity_configuration.dart';
import 'content_collection.dart';

abstract class ContentCatalogProvider {
  Future<List<ContentCollection>> fetchHomeCollections(IdentityConfiguration? activeIdentity);
}
