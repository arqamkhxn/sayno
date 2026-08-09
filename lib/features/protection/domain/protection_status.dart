enum ProtectionStatus {
  protected,
  protectionRequired,
  unknown,
}

extension ProtectionStatusLabel on ProtectionStatus {
  String get displayLabel {
    return switch (this) {
      ProtectionStatus.protected => 'Protected',
      ProtectionStatus.protectionRequired => 'Protection Required',
      ProtectionStatus.unknown => 'Checking Protection...',
    };
  }
}
