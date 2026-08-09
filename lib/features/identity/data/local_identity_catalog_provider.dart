import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/identity_profile.dart';
import '../domain/identity_catalog_provider.dart';

class LocalIdentityCatalogProvider implements IdentityCatalogProvider {
  final String _assetPath;

  LocalIdentityCatalogProvider({String assetPath = 'assets/data/identity_catalog.json'})
      : _assetPath = assetPath;

  @override
  Future<List<IdentityProfile>> fetchAvailableIdentities() async {
    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => IdentityProfile.fromJson(json)).toList();
    } catch (e) {
      // Fallback in case asset is missing
      return [];
    }
  }
}
