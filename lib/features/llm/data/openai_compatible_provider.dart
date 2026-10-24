// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/llm_chat.dart';
import '../domain/llm_provider.dart';
import '../domain/llm_provider_config.dart';
import '../domain/llm_tool.dart';

/// OpenAI-compatible Chat Completions API.
///
/// Подходит для OpenAI, OpenRouter, Ollama (OpenAI endpoint) и других
/// совместимых серверов. [LlmProviderConfig.baseUrl] должен указывать на
/// корень API, например `https://api.openai.com/v1`.
final class OpenAiCompatibleProvider extends LlmProvider {
  OpenAiCompatibleProvider(
    super.config, {
    required ApiClient client,
    required String? apiKey,
  }) : _client = client,
       _apiKey = apiKey;

  final ApiClient _client;
  final String? _apiKey;

  Map<String, String> get _headers => {
    if (_apiKey != null && _apiKey.isNotEmpty)
      'Authorization': 'Bearer $_apiKey',
  };

  @override
  Stream<LlmChunk> streamChat(LlmChatRequest request) async* {
    _validate(request);
    final response = await _client.streamLines(
      method: 'POST',
      path: '/chat/completions',
      headers: _headers,
      body: {
        'model': request.model,
        'messages': [for (final message in request.messages) message.toOpenAiJson()],
        'stream': true,
        'stream_options': {'include_usage': true},
        'max_tokens': request.maxTokens,
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.tools.isNotEmpty)
          'tools': [for (final tool in request.tools) tool.toOpenAiJson()],
      },
    );
    final lines = response.when<Stream<String>>(
      success: (stream) => stream,
      failure: (error) => throw error,
    );

    LlmUsage? lastUsage;
    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') {
          break;
        }
        if (payload.isEmpty) continue;
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, Object?>) continue;
        if (decoded['error'] != null) {
          throw const LlmException('LLM: провайдер вернул ошибку');
        }
        final usage = _parseUsage(decoded['usage']);
        if (usage != null) lastUsage = usage;

        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) {
          if (usage != null) yield LlmChunk(usage: usage);
          continue;
        }
        final choice = choices.first;
        if (choice is! Map<String, Object?>) continue;
        final delta = choice['delta'];
        final text = delta is Map<String, Object?> ? delta['content'] : null;
        final toolDeltas = _parseToolDeltas(delta);
        if ((text is String && text.isNotEmpty) || toolDeltas.isNotEmpty) {
          yield LlmChunk(
            delta: text is String ? text : '',
            toolCallDeltas: toolDeltas,
            usage: usage,
          );
        } else if (usage != null) {
          yield LlmChunk(usage: usage);
        }
      }
    } on AppException {
      rethrow;
    } on Object catch (e, s) {
      throw LlmException(
        'LLM: ошибка чтения streaming-ответа',
        cause: e,
        stackTrace: s,
      );
    }
    yield LlmChunk(done: true, usage: lastUsage);
  }

  @override
  Future<Result<List<double>>> embed(String input) async {
    final response = await _client.requestJson<List<double>>(
      method: 'POST',
      path: '/embeddings',
      headers: _headers,
      body: {'model': config.model, 'input': input},
      parse: (json) {
        if (json is! Map<String, Object?>) {
          throw const LlmException('LLM: некорректный ответ embeddings');
        }
        final data = json['data'];
        if (data is! List || data.isEmpty) {
          throw const LlmException('LLM: пустой ответ embeddings');
        }
        final first = data.first;
        final embedding = first is Map<String, Object?> ? first['embedding'] : null;
        if (embedding is! List) {
          throw const LlmException('LLM: нет вектора embeddings');
        }
        return [
          for (final value in embedding)
            if (value is num) value.toDouble(),
        ];
      },
    );
    return response;
  }

  static LlmUsage? _parseUsage(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    return LlmUsage(
      promptTokens: _int(raw['prompt_tokens']),
      completionTokens: _int(raw['completion_tokens']),
      totalTokens: _int(raw['total_tokens']),
    );
  }

  static List<LlmToolCallDelta> _parseToolDeltas(Object? delta) {
    if (delta is! Map<String, Object?>) return const [];
    final raw = delta['tool_calls'];
    if (raw is! List) return const [];
    final result = <LlmToolCallDelta>[];
    for (final item in raw) {
      if (item is! Map<String, Object?>) continue;
      final index = _int(item['index']) ?? 0;
      final function = item['function'];
      result.add(
        LlmToolCallDelta(
          index: index,
          id: item['id'] is String ? item['id'] as String : null,
          name: function is Map<String, Object?> && function['name'] is String
              ? function['name'] as String
              : null,
          argumentsJson:
              function is Map<String, Object?> &&
                  function['arguments'] is String
              ? function['arguments'] as String
              : null,
        ),
      );
    }
    return result;
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static void _validate(LlmChatRequest request) {
    if (request.model.trim().isEmpty) {
      throw const LlmException('LLM: не выбрана модель');
    }
    if (request.maxTokens <= 0) {
      throw const LlmException('LLM: лимит токенов должен быть больше нуля');
    }
  }
}
