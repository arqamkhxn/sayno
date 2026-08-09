import 'remote_catalog_provider.dart';

class FirebaseCatalogProvider implements RemoteCatalogProvider {
  @override
  Future<String?> fetchCatalog() async {
    // In Sprint 7A, this is a stub.
    // In the future, this will connect to Firebase Cloud Storage or Remote Config
    // to fetch 'curated_catalog.json'
    return null;
  }
}
