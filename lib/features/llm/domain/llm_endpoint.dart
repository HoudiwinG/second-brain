import 'llm_provider_type.dart';

/// Проверка базового URL LLM-провайдера.
///
/// Удалённые API обязаны использовать `https`: по `http` ключ ушёл бы в
/// открытом виде. Исключение — локальные серверы разработки (Ollama, vLLM),
/// доступные только через loopback.
abstract final class LlmEndpoint {
  static bool isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '[::1]';
  }

  static Uri? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// true, если URL допустим для хранения в конфигурации.
  static bool isValid(String raw) {
    final uri = tryParse(raw);
    if (uri == null) return false;
    if (uri.scheme == 'https') return true;
    return isLoopbackHost(uri.host);
  }

  /// true, если URL использует http для не-loopback хоста.
  static bool isInsecureRemote(String raw) {
    final uri = tryParse(raw);
    return uri != null && uri.scheme == 'http' && !isLoopbackHost(uri.host);
  }

  /// Требуется ли ключ для провайдера с таким base URL.
  static bool requiresApiKey(LlmProviderType type, String baseUrl) {
    if (type != LlmProviderType.openaiCompatible) return true;
    final uri = tryParse(baseUrl);
    return uri == null || !isLoopbackHost(uri.host);
  }
}
