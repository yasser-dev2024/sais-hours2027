import 'license_config.dart';

enum LicenseAccess {
  trial,
  activatedLifetime,
  trialExpired,
  clockManipulationDetected,
  invalidStoredLicense,
  storageUnavailable,
}

class LicenseSnapshot {
  const LicenseSnapshot({
    required this.access,
    required this.installationId,
    required this.agreementAccepted,
    required this.trialRemaining,
    this.detail,
  });

  final LicenseAccess access;
  final String installationId;
  final bool agreementAccepted;
  final Duration trialRemaining;
  final String? detail;

  bool get canUseApplication =>
      agreementAccepted &&
      (access == LicenseAccess.trial ||
          access == LicenseAccess.activatedLifetime);

  String get licenseStatus => access == LicenseAccess.activatedLifetime
      ? LicenseConfig.licenseStatusActivatedLifetime
      : access.name.toUpperCase();
}

class LicenseRecord {
  const LicenseRecord({
    required this.installationId,
    required this.trialStartedAtUtcMs,
    required this.lastSeenAtUtcMs,
    this.agreementAcceptedAtUtcMs,
    this.activationCode,
    this.activatedAtUtcMs,
  });

  static const schemaVersion = 1;

  final String installationId;
  final int trialStartedAtUtcMs;
  final int lastSeenAtUtcMs;
  final int? agreementAcceptedAtUtcMs;
  final String? activationCode;
  final int? activatedAtUtcMs;

  bool get agreementAccepted => agreementAcceptedAtUtcMs != null;

  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'installation_id': installationId,
    'trial_started_at_utc_ms': trialStartedAtUtcMs,
    'last_seen_at_utc_ms': lastSeenAtUtcMs,
    'agreement_accepted_at_utc_ms': agreementAcceptedAtUtcMs,
    'activation_code': activationCode,
    'activated_at_utc_ms': activatedAtUtcMs,
  };

  factory LicenseRecord.fromJson(Map<String, Object?> json) {
    if (_requiredInt(json, 'v') != schemaVersion) {
      throw const FormatException('Unsupported license-state version');
    }
    final installationId = _requiredString(json, 'installation_id');
    if (!RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(installationId)) {
      throw const FormatException('Invalid installation ID');
    }
    final trialStarted = _requiredInt(json, 'trial_started_at_utc_ms');
    final lastSeen = _requiredInt(json, 'last_seen_at_utc_ms');
    if (trialStarted <= 0 || lastSeen < trialStarted) {
      throw const FormatException('Invalid trial timestamps');
    }
    return LicenseRecord(
      installationId: installationId,
      trialStartedAtUtcMs: trialStarted,
      lastSeenAtUtcMs: lastSeen,
      agreementAcceptedAtUtcMs: _optionalInt(
        json,
        'agreement_accepted_at_utc_ms',
      ),
      activationCode: _optionalString(json, 'activation_code'),
      activatedAtUtcMs: _optionalInt(json, 'activated_at_utc_ms'),
    );
  }

  LicenseRecord copyWith({
    int? lastSeenAtUtcMs,
    int? agreementAcceptedAtUtcMs,
    String? activationCode,
    int? activatedAtUtcMs,
  }) => LicenseRecord(
    installationId: installationId,
    trialStartedAtUtcMs: trialStartedAtUtcMs,
    lastSeenAtUtcMs: lastSeenAtUtcMs ?? this.lastSeenAtUtcMs,
    agreementAcceptedAtUtcMs:
        agreementAcceptedAtUtcMs ?? this.agreementAcceptedAtUtcMs,
    activationCode: activationCode ?? this.activationCode,
    activatedAtUtcMs: activatedAtUtcMs ?? this.activatedAtUtcMs,
  );

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('Invalid $key');
    return value;
  }

  static int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int || value <= 0) throw FormatException('Invalid $key');
    return value;
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty)
      throw FormatException('Invalid $key');
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty || value.length > 4096) {
      throw FormatException('Invalid $key');
    }
    return value;
  }
}

class ActivationAttempt {
  const ActivationAttempt({required this.success, required this.message});

  final bool success;
  final String message;
}
