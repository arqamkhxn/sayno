import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/curated_content_item.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../providers/remote_catalog_provider.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  static const _localAssetPath = 'assets/data/default_curated_catalog.json';
  final RemoteCatalogProvider _remoteProvider;
  
  // In-memory cache
  List<CuratedContentItem>? _cachedCatalog;

  CatalogRepositoryImpl(this._remoteProvider);

  @override
  Future<List<CuratedContentItem>> getCatalogForIdentity(String identityId) async {
    if (_cachedCatalog == null) {
      await _loadCatalog();
    }
    
    return _cachedCatalog!
        .where((item) => item.identityTags.contains(identityId))
        .toList();
  }

  @override
  Future<void> refreshCatalog() async {
    try {
      final remoteData = await _remoteProvider.fetchCatalog();
      if (remoteData != null) {
        _cachedCatalog = _parseCatalog(remoteData);
        // We could also persist this to local storage (SQLite/SharedPreferences) here
      }
    } catch (e) {
      // If remote fetch fails, keep the current cache or local fallback
      print("Failed to fetch remote catalog: $e");
    }
  }

  Future<void> _loadCatalog() async {
    // 1. Try to load from remote (with timeout)
    try {
      final remoteData = await _remoteProvider.fetchCatalog().timeout(const Duration(seconds: 2));
      if (remoteData != null) {
        _cachedCatalog = _parseCatalog(remoteData);
        return;
      }
    } catch (_) {
      // Fallback to local on timeout or error
    }

    // 2. Fallback to bundled asset
    final jsonString = await rootBundle.loadString(_localAssetPath);
    _cachedCatalog = _parseCatalog(jsonString);
  }

  List<CuratedContentItem> _parseCatalog(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> contentList = data['content'];
    return contentList.map((item) => CuratedContentItem.fromJson(item)).toList();
  }
}
