import 'license_config.dart';
import 'license_models.dart';

class TrialAssessment {
  const TrialAssessment({required this.access, required this.remaining});

  final LicenseAccess access;
  final Duration remaining;
}

class TrialManager {
  const TrialManager();

  TrialAssessment assess(LicenseRecord record, DateTime nowUtc) {
    final nowMs = nowUtc.toUtc().millisecondsSinceEpoch;
    final rollbackLimit =
        nowMs + LicenseConfig.clockRollbackTolerance.inMilliseconds;
    if (rollbackLimit < record.lastSeenAtUtcMs ||
        rollbackLimit < record.trialStartedAtUtcMs) {
      return const TrialAssessment(
        access: LicenseAccess.clockManipulationDetected,
        remaining: Duration.zero,
      );
    }

    final effectiveNowMs = nowMs < record.lastSeenAtUtcMs
        ? record.lastSeenAtUtcMs
        : nowMs;
    final elapsedMs = effectiveNowMs - record.trialStartedAtUtcMs;
    final remainingMs = LicenseConfig.trialDuration.inMilliseconds - elapsedMs;
    if (remainingMs <= 0) {
      return const TrialAssessment(
        access: LicenseAccess.trialExpired,
        remaining: Duration.zero,
      );
    }
    return TrialAssessment(
      access: LicenseAccess.trial,
      remaining: Duration(milliseconds: remainingMs),
    );
  }
}
