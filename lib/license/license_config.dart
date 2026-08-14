import '../core/constants.dart';

abstract final class LicenseConfig {
  static const appId = AppConstants.packageId;
  static const licenseStatusActivatedLifetime = 'ACTIVATED_LIFETIME';
  static const trialDuration = Duration(days: 20);
  static const clockRollbackTolerance = Duration(minutes: 2);
  static const publicKeyBase64Url = String.fromEnvironment(
    'LICENSE_PUBLIC_KEY',
    defaultValue: 'ultuAW4fLM0RnC00T9zNi4zS1jFeF3mt37B1hOCbWrE',
  );
}
