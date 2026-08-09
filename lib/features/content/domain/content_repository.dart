import '../../identity/domain/identity_configuration.dart';
import 'content_collection.dart';

abstract class ContentRepository {
  Future<List<ContentCollection>> getHomeCollections(IdentityConfiguration? activeIdentity);
}
