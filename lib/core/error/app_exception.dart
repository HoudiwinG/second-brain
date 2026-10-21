/// Базовое исключение приложения.
///
/// Все осмысленные ошибки домена/данных унаследуются от него, чтобы
/// [Result.failure] и обработчики UI могли работать с единым типом.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  /// Человекочитаемое описание ошибки (без секретов!).
  final String message;

  /// Причина из низкоуровневого слоя (ните/платформенное исключение).
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() {
    final sb = StringBuffer('$runtimeType: $message');
    if (cause != null) sb.write(' | cause: $cause');
    return sb.toString();
  }
}

/// Операция не могла быть выполнена — неверные входные данные.
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause, super.stackTrace});
}

/// Ошибка слоя данных (БД, репозиторий, хранилище).
final class DataException extends AppException {
  const DataException(super.message, {super.cause, super.stackTrace});
}

/// Ошибка сетевого/API-слоя.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace, this.retryable = false});

  /// Повторяемая ли ошибка (сеть недоступна, таймаут, 5xx).
  final bool retryable;
}

/// Ошибка интеграции с внешним сервисом (почта, календарь и т.п.).
final class IntegrationException extends AppException {
  const IntegrationException(super.message, {super.cause, super.stackTrace});
}

/// Ошибка слоя LLM-провайдера.
final class LlmException extends AppException {
  const LlmException(super.message, {super.cause, super.stackTrace});
}

/// Все прочие неожиданные ошибки.
final class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.cause, super.stackTrace});
}
