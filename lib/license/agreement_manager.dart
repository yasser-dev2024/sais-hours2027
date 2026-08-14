import 'license_models.dart';

class AgreementManager {
  const AgreementManager();

  LicenseRecord accept(LicenseRecord record, DateTime acceptedAtUtc) {
    if (record.agreementAccepted) return record;
    return record.copyWith(
      agreementAcceptedAtUtcMs: acceptedAtUtc.toUtc().millisecondsSinceEpoch,
    );
  }
}
