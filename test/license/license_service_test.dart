import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horse_club_mobile/license/license_config.dart';
import 'package:horse_club_mobile/license/license_models.dart';
import 'package:horse_club_mobile/license/license_service.dart';
import 'package:horse_club_mobile/license/license_storage.dart';
import 'package:horse_club_mobile/license/license_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final algorithm = Ed25519();
  late SimpleKeyPair keyPair;
  late LicenseValidator validator;

  setUpAll(() async {
    keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    validator = LicenseValidator(
      publicKeyBase64Url: _base64Url(publicKey.bytes),
    );
  });

  test('تبدأ تجربة 20 يومًا قبل قبول التعهد ولا يمكن تأخيرها', () async {
    final storage = MemoryLicenseStorage();
    final clock = FakeClock(DateTime.utc(2026, 1, 1));
    final service = _service(storage, clock, validator);

    final first = await service.initialize();
    expect(first.access, LicenseAccess.trial);
    expect(first.agreementAccepted, isFalse);
    expect(first.canUseApplication, isFalse);
    expect(first.trialRemaining, LicenseConfig.trialDuration);

    clock.now = clock.now.add(const Duration(days: 5));
    final accepted = await service.acceptAgreement();
    expect(accepted.agreementAccepted, isTrue);
    expect(accepted.canUseApplication, isTrue);
    expect(accepted.trialRemaining, const Duration(days: 15));
  });

  test('تعمل كل الفترة ثم تقفل عند اكتمال اليوم العشرين', () async {
    final storage = MemoryLicenseStorage();
    final clock = FakeClock(DateTime.utc(2026, 2, 1));
    final service = _service(storage, clock, validator);
    await service.initialize();
    await service.acceptAgreement();

    clock.now = clock.now.add(const Duration(days: 19, hours: 23, minutes: 59));
    expect((await service.refresh()).access, LicenseAccess.trial);

    clock.now = clock.now.add(const Duration(minutes: 1));
    final expired = await service.refresh();
    expect(expired.access, LicenseAccess.trialExpired);
    expect(expired.canUseApplication, isFalse);
  });

  test('يكشف إرجاع ساعة الجهاز إلى الخلف ويقفل الدخول', () async {
    final storage = MemoryLicenseStorage();
    final clock = FakeClock(DateTime.utc(2026, 3, 1));
    final service = _service(storage, clock, validator);
    await service.initialize();
    await service.acceptAgreement();

    clock.now = clock.now.add(const Duration(days: 3));
    await service.refresh();
    clock.now = clock.now.subtract(const Duration(days: 1));

    final tampered = await service.refresh();
    expect(tampered.access, LicenseAccess.clockManipulationDetected);
    expect(tampered.canUseApplication, isFalse);
  });

  test('يرفض الرمز الخاطئ ورمز جهاز آخر ورمز تطبيق آخر', () async {
    final storage = MemoryLicenseStorage();
    final clock = FakeClock(DateTime.utc(2026, 4, 1));
    final service = _service(storage, clock, validator);
    final snapshot = await service.initialize();

    expect((await service.activate('HM1.invalid.invalid')).success, isFalse);

    final otherDevice = await _signedLicense(
      algorithm,
      keyPair,
      installationId: 'OTHER-DEVICE-1234',
    );
    expect((await service.activate(otherDevice)).success, isFalse);

    final otherApp = await _signedLicense(
      algorithm,
      keyPair,
      installationId: snapshot.installationId,
      appId: 'com.example.other',
    );
    expect((await service.activate(otherApp)).success, isFalse);
  });

  test(
    'التفعيل الصحيح دائم بعد الإغلاق وإعادة التشغيل والتحديث وبدون شبكة',
    () async {
      final storage = MemoryLicenseStorage();
      final clock = FakeClock(DateTime.utc(2026, 5, 1));
      final service = _service(storage, clock, validator);
      final first = await service.initialize();
      await service.acceptAgreement();
      clock.now = clock.now.add(const Duration(days: 20));
      expect((await service.refresh()).access, LicenseAccess.trialExpired);

      final code = await _signedLicense(
        algorithm,
        keyPair,
        installationId: first.installationId,
      );
      final activation = await service.activate(code);
      expect(activation.success, isTrue);
      expect(service.snapshot!.access, LicenseAccess.activatedLifetime);
      expect(
        service.snapshot!.licenseStatus,
        LicenseConfig.licenseStatusActivatedLifetime,
      );

      clock.now = clock.now.add(const Duration(days: 900));
      final afterRestartOrUpdate = _service(storage, clock, validator);
      final restored = await afterRestartOrUpdate.initialize();
      expect(restored.access, LicenseAccess.activatedLifetime);
      expect(restored.canUseApplication, isTrue);
      expect(restored.installationId, first.installationId);
    },
  );

  test('يقفل عند تعديل التفعيل المحفوظ أو إفساد سجل الترخيص', () async {
    final storage = MemoryLicenseStorage();
    final clock = FakeClock(DateTime.utc(2026, 6, 1));
    final service = _service(storage, clock, validator);
    final first = await service.initialize();
    await service.acceptAgreement();
    final code = await _signedLicense(
      algorithm,
      keyPair,
      installationId: first.installationId,
    );
    expect((await service.activate(code)).success, isTrue);

    final decoded = jsonDecode(storage.value!) as Map<String, dynamic>;
    decoded['activation_code'] = '${decoded['activation_code']}X';
    storage.value = jsonEncode(decoded);
    expect(
      (await service.refresh()).access,
      LicenseAccess.invalidStoredLicense,
    );

    storage.value = '{broken';
    expect((await service.refresh()).access, LicenseAccess.storageUnavailable);
  });

  test('يتحقق التطبيق من رمز أنشأته أداة المطور المنفصلة', () async {
    const generatorOutput =
        'HM1.eyJ2IjoxLCJhcHBfaWQiOiJjb20uYWJ1YW1tYXIuaG9yc2VjbHViLm1vYmlsZTIwMjYiLCJpbnN0YWxsYXRpb25faWQiOiJURVNULURFVklDRS0xMjM0IiwibGljZW5zZV90eXBlIjoibGlmZXRpbWUiLCJpc3N1ZWRfYXQiOiIyMDI2LTA4LTE0VDE5OjIwOjEzKzAwOjAwIn0.7icW2KwXcLxiwPVAe1X4DmJnxIy_2K2c9fIGxyMrWKo_HxRIOd_Uy73P7y_bQ5h7Rw8URapRCu0jbZDskwEpCQ';
    final result = await LicenseValidator().validate(
      generatorOutput,
      installationId: 'TEST-DEVICE-1234',
    );
    expect(result.valid, isTrue);
  });
}

LicenseService _service(
  MemoryLicenseStorage storage,
  FakeClock clock,
  LicenseValidator validator,
) => LicenseService(storage: storage, validator: validator, clock: clock.call);

Future<String> _signedLicense(
  Ed25519 algorithm,
  SimpleKeyPair keyPair, {
  required String installationId,
  String appId = LicenseConfig.appId,
}) async {
  final payload = utf8.encode(
    jsonEncode({
      'v': 1,
      'app_id': appId,
      'installation_id': installationId,
      'license_type': 'lifetime',
      'issued_at': '2026-01-01T00:00:00Z',
    }),
  );
  final signature = await algorithm.sign(payload, keyPair: keyPair);
  return 'HM1.${_base64Url(payload)}.${_base64Url(signature.bytes)}';
}

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;
}

class MemoryLicenseStorage implements LicenseStorage {
  String? value;

  @override
  Future<String?> readState() async => value;

  @override
  Future<void> writeState(String value) async => this.value = value;
}
