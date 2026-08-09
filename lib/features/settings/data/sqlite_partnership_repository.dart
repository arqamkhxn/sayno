import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/data/session_database.dart';
import '../domain/partnership.dart';
import 'partnership_repository.dart';

final partnershipRepositoryProvider = Provider<PartnershipRepository>((ref) {
  final db = ref.watch(sessionDatabaseProvider);
  return SqlitePartnershipRepository(
    database: db,
    firestore: FirebaseFirestore.instance,
  );
});

class SqlitePartnershipRepository implements PartnershipRepository {
  final SessionDatabase _database;
  final FirebaseFirestore _firestore;

  SqlitePartnershipRepository({
    required SessionDatabase database,
    required FirebaseFirestore firestore,
  })  : _database = database,
        _firestore = firestore;

  @override
  Future<Partnership?> getLocalPartnership() async {
    final db = await _database.database;
    final results = await db.query('partnerships', limit: 1);
    if (results.isEmpty) return null;
    return Partnership.fromSqlite(results.first);
  }

  @override
  Future<void> invitePartner({
    required String userEmail,
    required String userId,
    required String partnerEmail,
    required String verificationToken,
  }) async {
    // 1. Write the pending partnership document to Firestore
    await _firestore.collection('partnerships').add({
      'userId': userId,
      'partnerEmail': partnerEmail,
      'partnerId': null,
      'verificationToken': verificationToken,
      'status': 'pending',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    // Register user profile if it doesn't exist (needed for the partner to look up their email)
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    if (!userSnapshot.exists) {
      await userDoc.set({
        'email': userEmail,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    // 2. Persist local SQLite record (overwriting any previous ones)
    final db = await _database.database;
    await db.delete('partnerships');
    await db.insert('partnerships', {
      'partner_email': partnerEmail,
      'partner_uid': null,
      'status': 'pending',
    });
  }

  @override
  Future<void> acceptInvitation({
    required String token,
    required String partnerEmail,
    required String partnerUid,
  }) async {
    // 1. Query Firestore to find the matching pending partnership doc
    final query = await _firestore
        .collection('partnerships')
        .where('verificationToken', isEqualTo: token)
        .where('partnerEmail', isEqualTo: partnerEmail)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid verification token or email mismatch.');
    }

    final doc = query.docs.first;
    final creatorId = doc.get('userId') as String;

    // 2. Query Firestore to retrieve the creator's user profile (for the email)
    final creatorSnapshot = await _firestore.collection('users').doc(creatorId).get();
    final creatorEmail = creatorSnapshot.exists
        ? (creatorSnapshot.get('email') as String)
        : 'Partner';

    // 3. Update Firestore document status and link partner ID
    await doc.reference.update({
      'partnerId': partnerUid,
      'status': 'active',
    });

    // 4. Also register partner's user profile if it doesn't exist
    final partnerUserDoc = _firestore.collection('users').doc(partnerUid);
    final partnerUserSnapshot = await partnerUserDoc.get();
    if (!partnerUserSnapshot.exists) {
      await partnerUserDoc.set({
        'email': partnerEmail,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    // 5. Update local database cache
    final db = await _database.database;
    await db.delete('partnerships');
    await db.insert('partnerships', {
      'partner_email': creatorEmail,
      'partner_uid': creatorId,
      'status': 'active',
    });
  }

  @override
  Future<Partnership?> syncPartnership(String userId) async {
    final local = await getLocalPartnership();
    if (local == null) return null;

    if (local.status == PartnershipStatus.pending) {
      // Look for a partnership created by this user
      final query = await _firestore
          .collection('partnerships')
          .where('userId', isEqualTo: userId)
          .where('partnerEmail', isEqualTo: local.partnerEmail)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final statusStr = doc.get('status') as String;
        final partnerId = doc.get('partnerId') as String?;

        if (statusStr == 'active' && partnerId != null) {
          final updated = local.copyWith(
            status: PartnershipStatus.active,
            partnerUid: partnerId,
          );
          final db = await _database.database;
          await db.delete('partnerships');
          await db.insert('partnerships', updated.toSqlite());
          return updated;
        }
      }
    } else if (local.status == PartnershipStatus.active) {
      // Double check active relationship is still active remotely
      final query = await _firestore
          .collection('partnerships')
          .where('userId', isEqualTo: userId)
          .where('partnerId', isEqualTo: local.partnerUid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      // If not found, check inverse (where current user was invited by the partner)
      if (query.docs.isEmpty) {
        final inverseQuery = await _firestore
            .collection('partnerships')
            .where('userId', isEqualTo: local.partnerUid)
            .where('partnerId', isEqualTo: userId)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (inverseQuery.docs.isEmpty) {
          // No longer active remotely, clear locally
          await clearLocalPartnership();
          return null;
        }
      }
    }
    return local;
  }

  @override
  Future<void> clearLocalPartnership() async {
    final db = await _database.database;
    await db.delete('partnerships');
  }
}
