enum PartnershipStatus {
  pending,
  active,
  none,
}

class Partnership {
  final int? id;
  final String partnerEmail;
  final String? partnerUid;
  final PartnershipStatus status;

  const Partnership({
    this.id,
    required this.partnerEmail,
    this.partnerUid,
    required this.status,
  });

  /// Factory constructor to create a Partnership from local SQLite database representation.
  factory Partnership.fromSqlite(Map<String, dynamic> json) {
    return Partnership(
      id: json['id'] as int?,
      partnerEmail: json['partner_email'] as String,
      partnerUid: json['partner_uid'] as String?,
      status: PartnershipStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PartnershipStatus.none,
      ),
    );
  }

  /// Converts the Partnership to a local SQLite database representation.
  Map<String, dynamic> toSqlite() {
    return {
      if (id != null) 'id': id,
      'partner_email': partnerEmail,
      'partner_uid': partnerUid,
      'status': status.name,
    };
  }

  /// Factory constructor to create a Partnership from Firestore document snapshot/data.
  factory Partnership.fromFirestore(Map<String, dynamic> json, {int? localId}) {
    return Partnership(
      id: localId,
      partnerEmail: json['partnerEmail'] as String,
      partnerUid: json['partnerId'] as String?,
      status: PartnershipStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PartnershipStatus.none,
      ),
    );
  }

  /// Converts the Partnership to a Firestore document representation.
  Map<String, dynamic> toFirestore(String userId, String verificationToken) {
    return {
      'userId': userId,
      'partnerEmail': partnerEmail,
      'partnerId': partnerUid,
      'status': status.name,
      'verificationToken': verificationToken,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Partnership copyWith({
    int? id,
    String? partnerEmail,
    String? partnerUid,
    PartnershipStatus? status,
  }) {
    return Partnership(
      id: id ?? this.id,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      partnerUid: partnerUid ?? this.partnerUid,
      status: status ?? this.status,
    );
  }
}
