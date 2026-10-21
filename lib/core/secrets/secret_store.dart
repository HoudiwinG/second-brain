import '../error/app_exception.dart';
import '../result/result.dart';

/// Интерфейс хранилища секретов (API-ключи, OAuth-токены, ключи шифрования).
///
/// Реализация по умолчанию — [SecureSecretStore] поверх flutter_secure_storage
/// (DPAPI на Windows, Keychain/Keystore на мобильных). Никакие секреты
/// не должны попадать в plaintext БД или логи.
abstract interface class SecretStore {
  /// Читает значение по ключу. Возвращает null, если ключа нет.
  Future<Result<String?>> read(String key);

  /// Записывает (или перезаписывает) значение по ключу.
  Future<Result<void>> write(String key, String value);

  /// Удаляет ключ. Отсутствующий ключ не считается ошибкой.
  Future<Result<void>> delete(String key);

  /// Очищает всё хранилище (для кнопки «удалить все данные»).
  Future<Result<void>> clear();
}

/// Вспомогательный метод: схлопнуть [AppException] в один тип ошибки чтения.
AppException secretDataError(String operation, Object cause, [StackTrace? stack]) =>
    DataException('SecretStore: не удалось $operation', cause: cause, stackTrace: stack);
