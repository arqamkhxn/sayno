enum ReleaseStatus {
  cooldown,
  pending_approval,
  grace_window,
  completed,
  canceled,
}

class ReleaseRequest {
  final int? id;
  final DateTime requestedAtUtc;
  final int cooldownDurationSeconds;
  final ReleaseStatus status;
  final DateTime? partnerApprovedAtUtc;
  final DateTime? graceWindowExpiresAtUtc;

  ReleaseRequest({
    this.id,
    required this.requestedAtUtc,
    required this.cooldownDurationSeconds,
    required this.status,
    this.partnerApprovedAtUtc,
    this.graceWindowExpiresAtUtc,
  });

  factory ReleaseRequest.fromMap(Map<String, dynamic> map) {
    return ReleaseRequest(
      id: map['id'] as int?,
      requestedAtUtc: DateTime.parse(map['requested_at_utc'] as String),
      cooldownDurationSeconds: map['cooldown_duration_seconds'] as int,
      status: ReleaseStatus.values.firstWhere(
        (e) => e.name == map['status'] as String,
        orElse: () => ReleaseStatus.cooldown,
      ),
      partnerApprovedAtUtc: map['partner_approved_at_utc'] != null
          ? DateTime.parse(map['partner_approved_at_utc'] as String).toUtc()
          : null,
      graceWindowExpiresAtUtc: map['grace_window_expires_at_utc'] != null
          ? DateTime.parse(map['grace_window_expires_at_utc'] as String).toUtc()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'requested_at_utc': requestedAtUtc.toIso8601String(),
      'cooldown_duration_seconds': cooldownDurationSeconds,
      'status': status.name,
      'partner_approved_at_utc': partnerApprovedAtUtc?.toIso8601String(),
      'grace_window_expires_at_utc': graceWindowExpiresAtUtc?.toIso8601String(),
    };
  }

  ReleaseRequest copyWith({
    int? id,
    DateTime? requestedAtUtc,
    int? cooldownDurationSeconds,
    ReleaseStatus? status,
    DateTime? partnerApprovedAtUtc,
    DateTime? graceWindowExpiresAtUtc,
  }) {
    return ReleaseRequest(
      id: id ?? this.id,
      requestedAtUtc: requestedAtUtc ?? this.requestedAtUtc,
      cooldownDurationSeconds: cooldownDurationSeconds ?? this.cooldownDurationSeconds,
      status: status ?? this.status,
      partnerApprovedAtUtc: partnerApprovedAtUtc ?? this.partnerApprovedAtUtc,
      graceWindowExpiresAtUtc: graceWindowExpiresAtUtc ?? this.graceWindowExpiresAtUtc,
    );
  }
}
