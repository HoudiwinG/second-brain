import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../result/result.dart';
import 'secret_store.dart';

/// Реализация [SecretStore] на базе flutter_secure_storage.
///
/// Windows: DPAPI, iOS: Keychain, Android: Keystore.
final class SecureSecretStore implements SecretStore {
  SecureSecretStore();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<Result<String?>> read(String key) async {
    try {
      return Result.success(await _storage.read(key: key));
    } on Exception catch (e, s) {
      return Result.failure(secretDataError('прочитать ключ "$key"', e, s));
    }
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return const Result.success(null);
    } on Exception catch (e, s) {
      return Result.failure(secretDataError('записать ключ "$key"', e, s));
    }
  }

  @override
  Future<Result<void>> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return const Result.success(null);
    } on Exception catch (e, s) {
      return Result.failure(secretDataError('удалить ключ "$key"', e, s));
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _storage.deleteAll();
      return const Result.success(null);
    } on Exception catch (e, s) {
      return Result.failure(secretDataError('очистить хранилище', e, s));
    }
  }
}
