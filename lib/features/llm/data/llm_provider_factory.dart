import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../domain/llm_provider.dart';
import '../domain/llm_provider_config.dart';
import '../domain/llm_provider_type.dart';
import 'anthropic_provider.dart';
import 'google_provider.dart';
import 'openai_compatible_provider.dart';

/// Создаёт провайдер по сохранённой конфигурации.
///
/// [client] можно подменить в тестах. Один HTTP-клиент переиспользуется
/// всеми провайдерами; закрывается вместе с фабрикой.
final class LlmProviderFactory {
  LlmProviderFactory({
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 60),
    this.maxRetries = 3,
    this.retryDelay,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxRetries;
  final Future<void> Function(Duration)? retryDelay;

  LlmProvider create({
    required LlmProviderConfig config,
    required String? apiKey,
  }) {
    final api = ApiClient(
      baseUrl: config.baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      maxRetries: maxRetries,
      client: _client,
      delay: retryDelay,
    );
    return switch (config.type) {
      LlmProviderType.openai ||
      LlmProviderType.openaiCompatible => OpenAiCompatibleProvider(
        config,
        client: api,
        apiKey: apiKey,
      ),
      LlmProviderType.anthropic => AnthropicProvider(
        config,
        client: api,
        apiKey: apiKey,
      ),
      LlmProviderType.google => GoogleProvider(
        config,
        client: api,
        apiKey: apiKey,
      ),
    };
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
