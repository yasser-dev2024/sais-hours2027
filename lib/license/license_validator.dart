import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'license_config.dart';

class LicenseValidation {
  const LicenseValidation._({
    required this.valid,
    required this.message,
    this.normalizedCode,
  });

  factory LicenseValidation.valid(String normalizedCode) => LicenseValidation._(
    valid: true,
    message: 'تم التفعيل بنجاح',
    normalizedCode: normalizedCode,
  );

  factory LicenseValidation.invalid([
    String message = 'رمز التفعيل غير صحيح',
  ]) => LicenseValidation._(valid: false, message: message);

  final bool valid;
  final String message;
  final String? normalizedCode;
}

class LicenseValidator {
  LicenseValidator({
    String publicKeyBase64Url = LicenseConfig.publicKeyBase64Url,
    String appId = LicenseConfig.appId,
  }) : _publicKeyBase64Url = publicKeyBase64Url,
       _appId = appId;

  static final RegExp _codePattern = RegExp(
    r'^HM1\.([A-Za-z0-9_-]{20,3072})\.([A-Za-z0-9_-]{80,128})$',
  );

  final String _publicKeyBase64Url;
  final String _appId;
  final Ed25519 _algorithm = Ed25519();

  Future<LicenseValidation> validate(
    String source, {
    required String installationId,
  }) async {
    final code = source.trim();
    final match = _codePattern.firstMatch(code);
    if (match == null) return LicenseValidation.invalid();
    try {
      final payloadBytes = _decode(match.group(1)!);
      final signatureBytes = _decode(match.group(2)!);
      final publicKeyBytes = _decode(_publicKeyBase64Url);
      if (payloadBytes.length > 2048 ||
          signatureBytes.length != 64 ||
          publicKeyBytes.length != 32) {
        return LicenseValidation.invalid();
      }
      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(signatureBytes, publicKey: publicKey);
      final signatureValid = await _algorithm.verify(
        payloadBytes,
        signature: signature,
      );
      if (!signatureValid) return LicenseValidation.invalid();

      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != 1 ||
          decoded['app_id'] != _appId ||
          decoded['installation_id'] != installationId ||
          decoded['license_type'] != 'lifetime') {
        return LicenseValidation.invalid(
          'رمز التفعيل لا يخص هذا التطبيق أو هذا الجهاز',
        );
      }
      final issuedAt = decoded['issued_at'];
      if (issuedAt is! String || DateTime.tryParse(issuedAt)?.isUtc != true) {
        return LicenseValidation.invalid();
      }
      return LicenseValidation.valid(code);
    } on FormatException {
      return LicenseValidation.invalid();
    } on ArgumentError {
      return LicenseValidation.invalid();
    }
  }

  static List<int> _decode(String value) =>
      base64Url.decode(base64Url.normalize(value));
}
