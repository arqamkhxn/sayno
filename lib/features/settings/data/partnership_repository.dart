import '../domain/partnership.dart';

abstract class PartnershipRepository {
  /// Retrieves the locally stored partnership status, if any.
  Future<Partnership?> getLocalPartnership();

  /// Sends a partnership invitation to a partner by writing the document in Firestore
  /// and saving the state locally in SQLite.
  Future<void> invitePartner({
    required String userEmail,
    required String userId,
    required String partnerEmail,
    required String verificationToken,
  });

  /// Accepts a partnership invitation using the verification token.
  /// Validates the token in Firestore, updates the status, sets the partnerUid,
  /// and persists the active state locally in SQLite.
  Future<void> acceptInvitation({
    required String token,
    required String partnerEmail,
    required String partnerUid,
  });

  /// Syncs the partnership status with Firestore (e.g., checks if a pending
  /// invitation was accepted by the partner, or if the relationship is active).
  Future<Partnership?> syncPartnership(String userId);

  /// Clears local database partnership records.
  Future<void> clearLocalPartnership();
}
