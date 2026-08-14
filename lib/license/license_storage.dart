import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LicenseStorage {
  Future<String?> readState();

  Future<void> writeState(String value);
}

class SecureLicenseStorage implements LicenseStorage {
  SecureLicenseStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _stateKey = 'horse_manager_license_state_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readState() => _storage.read(key: _stateKey);

  @override
  Future<void> writeState(String value) =>
      _storage.write(key: _stateKey, value: value);
}
