import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/app_exception.dart';
import '../logging/app_logger.dart';
import '../result/result.dart';

/// Единый сетевой клиент приложения.
///
/// Все сетевые вызовы (LLM, почта, календарь) обязаны идти через него:
/// таймауты, retry и логирование сосредоточены здесь. Содержимое запросов
/// и заголовки с секретами никогда не логируются.
final class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 60),
    this.maxRetries = 3,
    this.headersProvider,
    http.Client? client,
    Future<void> Function(Duration)? delay,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _delay = delay ?? Future<void>.delayed;

  /// Базовый URL целевого сервиса (LLM-агрегатор, почтовый API и т.п.).
  final String baseUrl;

  /// Таймаут установки соединения / отправки запроса.
  final Duration connectTimeout;

  /// Таймаут ожидания данных (в том числе следующего SSE-события).
  final Duration receiveTimeout;

  /// Максимум попыток при retryable-ошибке (включая первую).
  final int maxRetries;

  /// Провайдер дополнительных заголовков (Authorization и т.п.).
  ///
  /// Заголовки применяются только к запросу; значения не логируются.
  final Map<String, String> Function()? headersProvider;

  final http.Client _client;
  final bool _ownsClient;
  final Future<void> Function(Duration) _delay;

  /// Заголовки по умолчанию; [extra] переопределяет их.
  Map<String, String> defaultHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{'Accept': 'application/json'};
    final provided = headersProvider?.call();
    if (provided != null) headers.addAll(provided);
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  /// Собирает полный URL запроса.
  String buildUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final suffix = path.startsWith('/') ? path : '/$path';
    return '$base$suffix';
  }

  /// Возвращает true для HTTP 2xx.
  bool isSuccessful(int statusCode) => statusCode >= 200 && statusCode < 300;

  /// Выполняет запрос и возвращает потоковое тело ответа.
  ///
  /// Retry выполняется только до получения успешного ответа: повторять
  /// частично прочитанный SSE-поток нельзя — это продублирует текст в UI.
  Future<Result<http.StreamedResponse>> sendStreamed({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final url = buildUrl(path);
    final allHeaders = defaultHeaders(headers);
    String? encodedBody;
    if (body != null) {
      encodedBody = body is String ? body : jsonEncode(body);
      allHeaders.putIfAbsent(
        'Content-Type',
        () => 'application/json; charset=utf-8',
      );
    }

    NetworkException? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final request = http.Request(method.toUpperCase(), Uri.parse(url))
          ..headers.addAll(allHeaders);
        if (encodedBody != null) request.body = encodedBody;
        final streamed = await _client.send(request).timeout(connectTimeout);
        if (isSuccessful(streamed.statusCode)) {
          return Result.success(streamed);
        }

        // Тело ошибки не показываем и не логируем: оно может содержать
        // фрагменты пользовательского контекста.
        unawaited(streamed.stream.drain<void>().catchError((_) {}));
        final retryable = _isRetryableStatus(streamed.statusCode);
        lastError = NetworkException(
          'ApiClient: HTTP ${streamed.statusCode} ($method $path)',
          retryable: retryable,
          statusCode: streamed.statusCode,
        );
        AppLogger.w(
          'ApiClient: попытка $attempt/$maxRetries, HTTP ${streamed.statusCode}',
        );
        if (!retryable) return Result.failure(lastError);
      } on TimeoutException catch (e, s) {
        lastError = NetworkException(
          'ApiClient: таймаут запроса ($method $path)',
          cause: e,
          stackTrace: s,
          retryable: true,
        );
        AppLogger.w('ApiClient: попытка $attempt/$maxRetries, таймаут');
      } on http.ClientException catch (e, s) {
        lastError = NetworkException(
          'ApiClient: сетевая ошибка ($method $path)',
          cause: e,
          stackTrace: s,
          retryable: true,
        );
        AppLogger.w('ApiClient: попытка $attempt/$maxRetries, сетевая ошибка');
      } on Object catch (e, s) {
        lastError = NetworkException(
          'ApiClient: не удалось выполнить запрос ($method $path)',
          cause: e,
          stackTrace: s,
          retryable: false,
        );
        AppLogger.w('ApiClient: запрос не выполнен');
        return Result.failure(lastError);
      }

      if (attempt < maxRetries) {
        final backoff = Duration(milliseconds: 200 * (1 << (attempt - 1)));
        await _delay(backoff);
      }
    }
    return Result.failure(
      NetworkException(
        'ApiClient: исчерпан лимит повторов ($method $path)',
        cause: lastError,
      ),
    );
  }

  /// Выполняет JSON-запрос и парсит ответ.
  Future<Result<T>> requestJson<T>({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
    required T Function(Object? json) parse,
  }) async {
    final response = await sendStreamed(
      method: method,
      path: path,
      headers: headers,
      body: body,
    );
    return response.when(
      success: (streamed) async {
        try {
          final raw = await streamed.stream
              .timeout(receiveTimeout)
              .transform(utf8.decoder)
              .join();
          final decoded = raw.trim().isEmpty ? null : jsonDecode(raw);
          return Result.success(parse(decoded));
        } on TimeoutException catch (e, s) {
          return Result.failure(
            NetworkException(
              'ApiClient: таймаут чтения ответа ($path)',
              cause: e,
              stackTrace: s,
              retryable: true,
            ),
          );
        } on FormatException catch (e, s) {
          return Result.failure(
            NetworkException(
              'ApiClient: некорректный JSON ответа ($path)',
              cause: e,
              stackTrace: s,
            ),
          );
        } on AppException catch (e) {
          return Result.failure(e);
        } on Object catch (e, s) {
          return Result.failure(
            NetworkException(
              'ApiClient: не удалось прочитать ответ ($path)',
              cause: e,
              stackTrace: s,
            ),
          );
        }
      },
      failure: (error) async => Result<T>.failure(error),
    );
  }

  /// Открывает SSE-поток и возвращает строки без завершающих переводов.
  ///
  /// Ошибки HTTP приходят как [Failure]; ошибки чтения потока пробрасываются
  /// в подписку, чтобы вызывающий код мог показать локализованную ошибку.
  Future<Result<Stream<String>>> streamLines({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? additionalHeaders,
  }) async {
    final response = await sendStreamed(
      method: method,
      path: path,
      headers: {
        'Accept': 'text/event-stream',
        ...?headers,
        ...?additionalHeaders,
      },
      body: body,
    );
    return response.when(
      success: (streamed) {
        final lines = streamed.stream
            .timeout(receiveTimeout)
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .handleError((Object error, StackTrace stack) {
              if (error is TimeoutException) {
                throw NetworkException(
                  'ApiClient: таймаут SSE-потока ($path)',
                  cause: error,
                  stackTrace: stack,
                  retryable: true,
                );
              }
              throw NetworkException(
                'ApiClient: ошибка чтения SSE-потока ($path)',
                cause: error,
                stackTrace: stack,
              );
            });
        return Result.success(lines);
      },
      failure: (error) => Result.failure(error),
    );
  }

  /// Закрывает внутренний HTTP-клиент, если он создан этим объектом.
  void close() {
    if (_ownsClient) _client.close();
  }

  static bool _isRetryableStatus(int status) =>
      status == 408 || status == 425 || status == 429 || status >= 500;
}
