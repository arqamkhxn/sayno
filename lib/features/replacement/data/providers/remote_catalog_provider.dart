abstract class RemoteCatalogProvider {
  /// Fetches the remote catalog JSON string.
  /// Returns null if the fetch fails or is unavailable.
  Future<String?> fetchCatalog();
}
