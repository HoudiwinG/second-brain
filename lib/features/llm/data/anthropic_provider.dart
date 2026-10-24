// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/llm_chat.dart';
import '../domain/llm_message.dart';
import '../domain/llm_provider.dart';
import '../domain/llm_tool.dart';

/// Anthropic Messages API (streaming).
final class AnthropicProvider extends LlmProvider {
  AnthropicProvider(
    super.config, {
    required ApiClient client,
    required String? apiKey,
  }) : _client = client,
       _apiKey = apiKey;

  final ApiClient _client;
  final String? _apiKey;

  Map<String, String> get _headers => {
    'anthropic-version': '2023-06-01',
    if (_apiKey != null && _apiKey.isNotEmpty) 'x-api-key': _apiKey,
  };

  @override
  Stream<LlmChunk> streamChat(LlmChatRequest request) async* {
    _validate(request);
    final system = request.messages
        .where((message) => message.role == LlmRole.system)
        .map((message) => message.content)
        .where((content) => content.trim().isNotEmpty)
        .join('\n\n');
    final messages = [
      for (final message in request.messages)
        if (message.role != LlmRole.system)
          {
            'role': message.role == LlmRole.assistant ? 'assistant' : 'user',
            'content': message.content,
          },
    ];

    final response = await _client.streamLines(
      method: 'POST',
      path: '/messages',
      headers: _headers,
      body: {
        'model': request.model,
        'max_tokens': request.maxTokens,
        'stream': true,
        if (system.isNotEmpty) 'system': system,
        'messages': messages,
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.tools.isNotEmpty)
          'tools': [for (final tool in request.tools) tool.toAnthropicJson()],
      },
    );
    final lines = response.when<Stream<String>>(
      success: (stream) => stream,
      failure: (error) => throw error,
    );

    LlmUsage? lastUsage;
    final toolMeta = <int, ({String? id, String? name})>{};
    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, Object?>) continue;
        final type = decoded['type'];
        if (type == 'error') {
          throw const LlmException('LLM: провайдер вернул ошибку');
        }
        final usage = _parseUsage(decoded);
        if (usage != null) {
          lastUsage = lastUsage?.merge(usage) ?? usage;
        }

        if (type == 'content_block_start') {
          final index = _int(decoded['index']) ?? 0;
          final block = decoded['content_block'];
          if (block is Map<String, Object?> && block['type'] == 'tool_use') {
            final id = block['id'] is String ? block['id'] as String : null;
            final name = block['name'] is String
                ? block['name'] as String
                : null;
            toolMeta[index] = (id: id, name: name);
            yield LlmChunk(
              toolCallDeltas: [
                LlmToolCallDelta(index: index, id: id, name: name),
              ],
            );
          }
          continue;
        }
        if (type == 'content_block_delta') {
          final index = _int(decoded['index']) ?? 0;
          final delta = decoded['delta'];
          if (delta is Map<String, Object?>) {
            if (delta['type'] == 'text_delta' && delta['text'] is String) {
              final text = delta['text'] as String;
              if (text.isNotEmpty) yield LlmChunk(delta: text);
            } else if (delta['type'] == 'input_json_delta') {
              final meta = toolMeta[index];
              yield LlmChunk(
                toolCallDeltas: [
                  LlmToolCallDelta(
                    index: index,
                    id: meta?.id,
                    name: meta?.name,
                    argumentsJson: delta['partial_json'] is String
                        ? delta['partial_json'] as String
                        : null,
                  ),
                ],
              );
            }
          }
          continue;
        }
        if (type == 'message_stop') {
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

  static LlmUsage? _parseUsage(Map<String, Object?> json) {
    final usage = json['usage'];
    if (usage is Map<String, Object?>) {
      return LlmUsage(
        promptTokens: _int(usage['input_tokens']),
        completionTokens: _int(usage['output_tokens']),
      );
    }
    final message = json['message'];
    if (message is Map<String, Object?> && message['usage'] is Map) {
      final nested = message['usage'] as Map<String, Object?>;
      return LlmUsage(
        promptTokens: _int(nested['input_tokens']),
        completionTokens: _int(nested['output_tokens']),
      );
    }
    return null;
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
