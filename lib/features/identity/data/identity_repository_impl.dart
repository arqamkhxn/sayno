import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/identity_configuration.dart';
import '../domain/identity_repository.dart';
import 'local_identity_data_source.dart';

class IdentityRepositoryImpl implements IdentityRepository {
  final LocalIdentityDataSource _localDataSource;

  IdentityRepositoryImpl(this._localDataSource);

  @override
  Future<IdentityConfiguration?> getActiveConfiguration() async {
    // 1. Try fetching from fast local DB
    final localConfig = await _localDataSource.getActiveConfiguration();
    if (localConfig != null) {
      return localConfig;
    }

    // 2. If missing (e.g. after fresh login/reinstall), try fetching from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('identity')
            .doc('current')
            .get();
        
        if (doc.exists && doc.data() != null) {
          final config = IdentityConfiguration.fromJson(doc.data()!);
          // Bootstrap local DB with recovered cloud data
          await _localDataSource.saveConfiguration(config);
          debugPrint('IdentitySync: Recovered identity from cloud');
          return config;
        }
      } catch (e) {
        debugPrint('IdentitySync Error: Failed to fetch from cloud: $e');
      }
    }
    
    return null;
  }

  @override
  Future<void> saveConfiguration(IdentityConfiguration config) async {
    // 1. Save to local SQLite for offline access and speed
    await _localDataSource.saveConfiguration(config);
    
    // 2. Dual-write to Firestore for cloud sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('identity')
            .doc('current')
            .set(config.toJson());
        debugPrint('IdentitySync: Synced identity to cloud');
      } catch (e) {
        debugPrint('IdentitySync Error: Failed to sync to cloud: $e');
      }
    }
  }

  @override
  Future<void> clearAll() async {
    await _localDataSource.clearAllData();
  }
}
