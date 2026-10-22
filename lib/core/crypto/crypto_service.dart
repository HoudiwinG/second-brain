import '../result/result.dart';

/// Шифрование чувствительных полей «в покое» (PROMPT.md, модуль безопасности).
///
/// Контракт этапа 0: реализации появятся на stage-01+ (шифрование заметок,
/// финансовых записей и приватных полей). Ключи хранятся только в
/// `SecretStore`, а не в БД или логах (ADR-003).
///
/// Все методы возвращают [Result], чтобы вызывающий слой не зависел от
/// исключений платформенного крипто-провайдера.
abstract interface class CryptoService {
  /// Шифрует [plaintext] и возвращает строку, пригодную для хранения в БД.
  Future<Result<String>> encrypt(String plaintext);

  /// Расшифровывает значение, полученное из [encrypt].
  Future<Result<String>> decrypt(String ciphertext);
}
