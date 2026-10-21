import 'dart:async';

import '../error/app_exception.dart';
import '../logging/app_logger.dart';
import '../result/result.dart';

/// Единый сетевой клиент приложения.
///
/// Заготовка этапа 0: контракт (таймауты, retry, логирование) уже задан,
/// HTTP-транспорт будет подключён на этапе интеграций отдельным ADR.
/// Все сетевые вызовы приложения (LLM, почта, календарь) обязаны
/// идти через него.
final class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.headersProvider,
  });

  /// Базовый URL целевого сервиса (LLM-агрегатор, почтовый API и т.п.).
  final String baseUrl;

  /// Таймаут установки соединения.
  final Duration connectTimeout;

  /// Таймаут получения ответа.
  final Duration receiveTimeout;

  /// Максимум повторов при retryable-ошибке.
  final int maxRetries;

  /// Провайдер дополнительных заголовков (Authorization и т.п.).
  final Map<String, String> Function()? headersProvider;

  /// Шаблон заголовков — заполняется при вызовах (Authorization и т.п.).
  Map<String, String> defaultHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    final extra = headersProvider?.call();
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  /// Собирает полный URL запроса.
  String buildUrl(String path) =>
      path.startsWith('http') ? path : '$baseUrl${path.startsWith('/') ? '' : '/'}$path';

  /// Возвращает true для HTTP 2xx.
  bool isSuccessful(int statusCode) => statusCode >= 200 && statusCode < 300;

  /// Точка выполнения запросов с retry.
  ///
  /// Этап 0 выполняет только контракт и логирование; реальный HTTP-вызов
  /// появится при подключении LLM-провайдеров (этап 3) и интеграций (этап 6).
  Future<Result<T>> request<T>({required T Function() parseStub}) async {
    const methodName = 'request';
    AppLogger.d('ApiClient.$methodName: executing stub (real HTTP on stage 3/6)');
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      // Заглушка ответа: на следующих этапах — реальный HTTP-вызов.
      const statusCode = 503;
      if (isSuccessful(statusCode)) {
        return Result.success(parseStub());
      }
      final error = NetworkException(
        'ApiClient: сервис недоступен (заглушка $statusCode)',
        cause: {'statusCode': statusCode},
        retryable: true,
      );
      AppLogger.w('ApiClient: попытка $attempt из $maxRetries не удалась', error.message);
      if (attempt == maxRetries) {
        return Result.failure(
          NetworkException('ApiClient: исчерпан лимит повторов', cause: error),
        );
      }
      // Экспоненциальная задержка для реального retry на следующих этапах.
      await Future<void>.delayed(Duration(milliseconds: 10 * (1 << attempt)));
    }
    // Недостижимо: цикл всегда завершается return внутри.
    return Result.failure(UnexpectedException('ApiClient: недостижимый код'));
  }
}
