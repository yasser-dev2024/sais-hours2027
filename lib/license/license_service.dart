import 'dart:convert';

import 'agreement_manager.dart';
import 'device_identifier.dart';
import 'license_models.dart';
import 'license_storage.dart';
import 'license_validator.dart';
import 'trial_manager.dart';

typedef UtcClock = DateTime Function();

class LicenseService {
  LicenseService({
    LicenseStorage? storage,
    LicenseValidator? validator,
    TrialManager trialManager = const TrialManager(),
    AgreementManager agreementManager = const AgreementManager(),
    DeviceIdentifier? deviceIdentifier,
    UtcClock? clock,
  }) : _storage = storage ?? SecureLicenseStorage(),
       _validator = validator ?? LicenseValidator(),
       _trialManager = trialManager,
       _agreementManager = agreementManager,
       _deviceIdentifier = deviceIdentifier ?? DeviceIdentifier(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final LicenseStorage _storage;
  final LicenseValidator _validator;
  final TrialManager _trialManager;
  final AgreementManager _agreementManager;
  final DeviceIdentifier _deviceIdentifier;
  final UtcClock _clock;

  LicenseRecord? _record;
  LicenseSnapshot? _snapshot;

  LicenseSnapshot? get snapshot => _snapshot;

  Future<LicenseSnapshot> initialize() async {
    try {
      final encoded = await _storage.readState();
      if (encoded == null) {
        final nowMs = _clock().toUtc().millisecondsSinceEpoch;
        _record = LicenseRecord(
          installationId: _deviceIdentifier.createInstallationId(),
          trialStartedAtUtcMs: nowMs,
          lastSeenAtUtcMs: nowMs,
        );
        await _persist(_record!);
      } else {
        _record = _decodeRecord(encoded);
      }
      return await _evaluateAndPersistLastSeen();
    } catch (_) {
      _record = null;
      return _snapshot = const LicenseSnapshot(
        access: LicenseAccess.storageUnavailable,
        installationId: 'غير متاح',
        agreementAccepted: false,
        trialRemaining: Duration.zero,
        detail: 'تعذر قراءة بيانات الترخيص الآمنة.',
      );
    }
  }

  Future<LicenseSnapshot> refresh() async => initialize();

  Future<LicenseSnapshot> acceptAgreement() async {
    final record = _record;
    if (record == null) return initialize();
    try {
      _record = _agreementManager.accept(record, _clock());
      await _persist(_record!);
      return await _evaluateAndPersistLastSeen();
    } catch (_) {
      return _snapshot = LicenseSnapshot(
        access: LicenseAccess.storageUnavailable,
        installationId: record.installationId,
        agreementAccepted: false,
        trialRemaining: Duration.zero,
        detail: 'تعذر حفظ الموافقة بطريقة آمنة.',
      );
    }
  }

  Future<ActivationAttempt> activate(String code) async {
    final record = _record;
    if (record == null) {
      return const ActivationAttempt(
        success: false,
        message: 'تعذر الوصول إلى بيانات الترخيص الآمنة',
      );
    }
    final validation = await _validator.validate(
      code,
      installationId: record.installationId,
    );
    if (!validation.valid) {
      return ActivationAttempt(success: false, message: validation.message);
    }
    try {
      final nowMs = _clock().toUtc().millisecondsSinceEpoch;
      _record = record.copyWith(
        lastSeenAtUtcMs: nowMs > record.lastSeenAtUtcMs
            ? nowMs
            : record.lastSeenAtUtcMs,
        activationCode: validation.normalizedCode,
        activatedAtUtcMs: nowMs,
      );
      await _persist(_record!);
      await _evaluateAndPersistLastSeen();
      return const ActivationAttempt(
        success: true,
        message: 'تم التفعيل بنجاح',
      );
    } catch (_) {
      return const ActivationAttempt(
        success: false,
        message: 'تعذر حفظ التفعيل بطريقة آمنة',
      );
    }
  }

  Future<LicenseSnapshot> _evaluateAndPersistLastSeen() async {
    var record = _record!;
    final now = _clock().toUtc();
    final activationCode = record.activationCode;
    if (activationCode != null) {
      final validation = await _validator.validate(
        activationCode,
        installationId: record.installationId,
      );
      if (!validation.valid) {
        return _snapshot = LicenseSnapshot(
          access: LicenseAccess.invalidStoredLicense,
          installationId: record.installationId,
          agreementAccepted: record.agreementAccepted,
          trialRemaining: Duration.zero,
          detail: 'بيانات التفعيل المحفوظة غير صحيحة أو تعرضت للتعديل.',
        );
      }
      await _advanceLastSeenIfNeeded(record, now);
      record = _record!;
      return _snapshot = LicenseSnapshot(
        access: LicenseAccess.activatedLifetime,
        installationId: record.installationId,
        agreementAccepted: record.agreementAccepted,
        trialRemaining: Duration.zero,
      );
    }

    final assessment = _trialManager.assess(record, now);
    if (assessment.access != LicenseAccess.clockManipulationDetected) {
      await _advanceLastSeenIfNeeded(record, now);
      record = _record!;
    }
    return _snapshot = LicenseSnapshot(
      access: assessment.access,
      installationId: record.installationId,
      agreementAccepted: record.agreementAccepted,
      trialRemaining: assessment.remaining,
      detail: assessment.access == LicenseAccess.clockManipulationDetected
          ? 'تم اكتشاف تغيير تاريخ الجهاز إلى الخلف.'
          : null,
    );
  }

  Future<void> _advanceLastSeenIfNeeded(
    LicenseRecord record,
    DateTime now,
  ) async {
    final nowMs = now.millisecondsSinceEpoch;
    if (nowMs <= record.lastSeenAtUtcMs) return;
    _record = record.copyWith(lastSeenAtUtcMs: nowMs);
    await _persist(_record!);
  }

  Future<void> _persist(LicenseRecord record) =>
      _storage.writeState(jsonEncode(record.toJson()));

  static LicenseRecord _decodeRecord(String encoded) {
    if (encoded.isEmpty || encoded.length > 8192) {
      throw const FormatException('Invalid license-state length');
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid license-state structure');
    }
    return LicenseRecord.fromJson(decoded);
  }
}
