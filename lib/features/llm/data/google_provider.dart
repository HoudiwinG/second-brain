// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/llm_chat.dart';
import '../domain/llm_message.dart';
import '../domain/llm_provider.dart';

/// Google Gemini API (streamGenerateContent + embedContent).
final class GoogleProvider extends LlmProvider {
  GoogleProvider(
    super.config, {
    required ApiClient client,
    required String? apiKey,
  }) : _client = client,
       _apiKey = apiKey;

  final ApiClient _client;
  final String? _apiKey;

  Map<String, String> get _headers => {
    if (_apiKey != null && _apiKey.isNotEmpty) 'x-goog-api-key': _apiKey,
  };

  String get _modelId {
    final model = config.model.trim();
    return model.startsWith('models/') ? model.substring(7) : model;
  }

  @override
  Stream<LlmChunk> streamChat(LlmChatRequest request) async* {
    _validate(request);
    final systems = request.messages
        .where((message) => message.role == LlmRole.system)
        .map((message) => message.content)
        .where((content) => content.trim().isNotEmpty)
        .toList();
    final contents = [
      for (final message in request.messages)
        if (message.role != LlmRole.system)
          {
            'role': message.role == LlmRole.assistant ? 'model' : 'user',
            'parts': [
              {'text': message.content},
            ],
          },
    ];
    final modelId = _modelId;
    final response = await _client.streamLines(
      method: 'POST',
      path:
          '/models/${Uri.encodeComponent(modelId)}'
          ':streamGenerateContent?alt=sse',
      headers: _headers,
      body: {
        'contents': contents,
        if (systems.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': systems.join('\n\n')},
            ],
          },
        'generationConfig': {
          'maxOutputTokens': request.maxTokens,
          if (request.temperature != null) 'temperature': request.temperature,
        },
        if (request.tools.isNotEmpty)
          'tools': [
            {
              'functionDeclarations': [
                for (final tool in request.tools) tool.toGoogleJson(),
              ],
            },
          ],
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
        if (payload.isEmpty || payload == '[DONE]') continue;
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, Object?>) continue;

        final promptFeedback = decoded['promptFeedback'];
        if (promptFeedback is Map<String, Object?> &&
            promptFeedback['blockReason'] != null) {
          throw const LlmException('LLM: запрос заблокирован провайдером');
        }
        final usage = _parseUsage(decoded['usageMetadata']);
        if (usage != null) lastUsage = usage;

        final candidates = decoded['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          if (usage != null) yield LlmChunk(usage: usage);
          continue;
        }
        final candidate = candidates.first;
        if (candidate is! Map<String, Object?>) continue;
        final content = candidate['content'];
        if (content is Map<String, Object?>) {
          final parts = content['parts'];
          if (parts is List) {
            final buffer = StringBuffer();
            for (final part in parts) {
              if (part is Map<String, Object?> && part['text'] is String) {
                buffer.write(part['text'] as String);
              }
            }
            if (buffer.isNotEmpty) {
              yield LlmChunk(delta: buffer.toString(), usage: usage);
            } else if (usage != null) {
              yield LlmChunk(usage: usage);
            }
          }
        }
        if (candidate['finishReason'] != null &&
            candidate['finishReason'] != 'STOP') {
          break;
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

  String get _embeddingModelId {
    final configured = config.embeddingModel?.trim();
    final raw = configured != null && configured.isNotEmpty
        ? configured
        : (config.type.defaultEmbeddingModel ?? config.model);
    return raw.startsWith('models/') ? raw.substring(7) : raw;
  }

  @override
  Future<Result<List<double>>> embed(String input) async {
    final modelId = _embeddingModelId;
    return _client.requestJson<List<double>>(
      method: 'POST',
      path: '/models/${Uri.encodeComponent(modelId)}:embedContent',
      headers: _headers,
      body: {
        'content': {
          'parts': [
            {'text': input},
          ],
        },
      },
      parse: (json) {
        if (json is! Map<String, Object?>) {
          throw const LlmException('LLM: некорректный ответ embeddings');
        }
        final embedding = json['embedding'];
        final values = embedding is Map<String, Object?>
            ? embedding['values']
            : null;
        if (values is! List) {
          throw const LlmException('LLM: нет вектора embeddings');
        }
        return [
          for (final value in values)
            if (value is num) value.toDouble(),
        ];
      },
    );
  }

  static LlmUsage? _parseUsage(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    return LlmUsage(
      promptTokens: _int(raw['promptTokenCount']),
      completionTokens: _int(raw['candidatesTokenCount']),
      totalTokens: _int(raw['totalTokenCount']),
    );
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
