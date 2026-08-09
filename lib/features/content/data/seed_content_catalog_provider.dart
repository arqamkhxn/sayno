import 'dart:convert';
import 'package:flutter/services.dart';

import '../../identity/domain/identity_configuration.dart';
import '../domain/content_catalog_provider.dart';
import '../domain/content_collection.dart';

class SeedContentCatalogProvider implements ContentCatalogProvider {
  final String _assetPath;

  SeedContentCatalogProvider({String assetPath = 'assets/data/seed_catalog.json'})
      : _assetPath = assetPath;

  @override
  Future<List<ContentCollection>> fetchHomeCollections(IdentityConfiguration? activeIdentity) async {
    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      final collections = jsonList.map((json) => ContentCollection.fromJson(json)).toList();

      // If no identity is configured, just return the raw seed catalog
      if (activeIdentity == null || !activeIdentity.isValid) {
        return collections;
      }

      // Gather all user goals for filtering
      final userGoals = <String>{};
      for (final identity in activeIdentity.identities) {
        userGoals.addAll(identity.selectedGoals);
      }

      // Filter or reorder collections based on identity/goals
      // For this mock seed implementation, we'll just prioritize collections 
      // that have at least one item matching the user's goals.
      final curatedCollections = <ContentCollection>[];
      final otherCollections = <ContentCollection>[];

      for (final collection in collections) {
        if (collection.type == CollectionType.continueLearning || collection.type == CollectionType.explore) {
          otherCollections.add(collection);
          continue;
        }

        bool matchesGoal = false;
        for (final item in collection.items) {
          if (item.tags.any((tag) => userGoals.contains(tag))) {
            matchesGoal = true;
            break;
          }
        }

        if (matchesGoal) {
          curatedCollections.add(collection);
        } else {
          otherCollections.add(collection);
        }
      }

      return [...curatedCollections, ...otherCollections];
    } catch (e, stack) {
      print('Error loading home collections: $e');
      print(stack);
      return [];
    }
  }
}
