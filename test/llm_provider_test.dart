import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/network/api_client.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/features/llm/data/anthropic_provider.dart';
import 'package:second_brain/features/llm/data/google_provider.dart';
import 'package:second_brain/features/llm/data/openai_compatible_provider.dart';
import 'package:second_brain/features/llm/domain/llm_chat.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';

LlmProviderConfig _config({
  required LlmProviderType type,
  String? baseUrl,
  String model = 'test-model',
  int maxTokens = 256,
}) => LlmProviderConfig(
  id: 1,
  type: type,
  displayName: 'Test',
  baseUrl: baseUrl ?? type.defaultBaseUrl,
  model: model,
  maxTokens: maxTokens,
  secretRef: 'llm.api_key.test',
  isDefault: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

LlmChatRequest _request({List<LlmMessage>? messages}) => LlmChatRequest(
  model: 'test-model',
  messages:
      messages ??
      const [
        LlmMessage(role: LlmRole.system, content: 'Будь краток.'),
        LlmMessage(role: LlmRole.user, content: 'Привет'),
      ],
  maxTokens: 256,
);

http.StreamedResponse _sse(String body, {http.BaseRequest? request}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: {'content-type': 'text/event-stream'},
    );

ApiClient _api(String baseUrl, http.Client client, {int maxRetries = 1}) =>
    ApiClient(
      baseUrl: baseUrl,
      client: client,
      maxRetries: maxRetries,
      delay: (_) async {},
    );

void main() {
  group('OpenAI-compatible provider', () {
    test('стримит текст, usage и передаёт ключ только в заголовке', () async {
      late http.Request captured;
      late String body;
      final client = MockClient.streaming((request, bodyStream) async {
        captured = request as http.Request;
        body = await bodyStream.transform(utf8.decoder).join();
        return _sse(
          'data: {"choices":[{"delta":{"content":"При"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"вет"}}],'
          '"usage":{"prompt_tokens":3,"completion_tokens":2,'
          '"total_tokens":5}}\n\n'
          'data: [DONE]\n\n',
          request: request,
        );
      });
      final config = _config(
        type: LlmProviderType.openai,
        baseUrl: 'https://api.test/v1',
      );
      final provider = OpenAiCompatibleProvider(
        config,
        client: _api(config.baseUrl, client),
        apiKey: 'sk-test-secret',
      );

      final response = (await provider.complete(_request())).unwrap();

      expect(response.content, 'Привет');
      expect(response.usage.promptTokens, 3);
      expect(response.usage.completionTokens, 2);
      expect(response.usage.totalTokens, 5);
      expect(captured.url.toString(), 'https://api.test/v1/chat/completions');
      expect(captured.headers['Authorization'], 'Bearer sk-test-secret');
      expect(body, isNot(contains('sk-test-secret')));

      final payload = jsonDecode(body) as Map<String, Object?>;
      expect(payload['model'], 'test-model');
      expect(payload['stream'], true);
      expect(payload['max_tokens'], 256);
      final messages = payload['messages'] as List<Object?>;
      expect(messages, hasLength(2));
      expect((messages.last as Map<String, Object?>)['content'], 'Привет');
    });

    test('собирает streaming tool calls', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.drain<void>();
        return _sse(
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
          '"id":"call_1","function":{"name":"add_note",'
          '"arguments":"{\\"title\\":"}}]}}]}\n\n'
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
          '"function":{"arguments":"\\"x\\"}"}}]}}]}\n\n'
          'data: [DONE]\n\n',
          request: request,
        );
      });
      final config = _config(
        type: LlmProviderType.openai,
        baseUrl: 'https://api.test/v1',
      );
      final provider = OpenAiCompatibleProvider(
        config,
        client: _api(config.baseUrl, client),
        apiKey: 'key',
      );

      final response = (await provider.complete(_request())).unwrap();

      expect(response.toolCalls, hasLength(1));
      expect(response.toolCalls.single.id, 'call_1');
      expect(response.toolCalls.single.name, 'add_note');
      expect(response.toolCalls.single.argumentsJson, '{"title":"x"}');
    });

    test('retry выполняется только до начала SSE-потока', () async {
      var calls = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.drain<void>();
        calls++;
        if (calls == 1) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('temporary error')),
            503,
            request: request,
          );
        }
        return _sse(
          'data: {"choices":[{"delta":{"content":"ok"}}]}\n\n'
          'data: [DONE]\n\n',
          request: request,
        );
      });
      final config = _config(
        type: LlmProviderType.openai,
        baseUrl: 'https://api.test/v1',
      );
      final provider = OpenAiCompatibleProvider(
        config,
        client: _api(config.baseUrl, client, maxRetries: 2),
        apiKey: 'key',
      );

      final response = (await provider.complete(_request())).unwrap();

      expect(response.content, 'ok');
      expect(calls, 2);
    });

    test('HTTP 401 не повторяется и возвращает ошибку без тела', () async {
      var calls = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.drain<void>();
        calls++;
        return http.StreamedResponse(
          Stream.value(utf8.encode('private provider body')),
          401,
          request: request,
        );
      });
      final config = _config(
        type: LlmProviderType.openai,
        baseUrl: 'https://api.test/v1',
      );
      final provider = OpenAiCompatibleProvider(
        config,
        client: _api(config.baseUrl, client, maxRetries: 3),
        apiKey: 'key',
      );

      final result = await provider.complete(_request());

      expect(result, isA<Failure<LlmResponse>>());
      expect(calls, 1);
      expect(result.toString(), isNot(contains('private provider body')));
    });

    test('embeddings парсит вектор', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.test/v1/embeddings');
        return http.Response(
          '{"data":[{"embedding":[0.1,0.25]}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final config = _config(
        type: LlmProviderType.openai,
        baseUrl: 'https://api.test/v1',
      );
      final provider = OpenAiCompatibleProvider(
        config,
        client: _api(config.baseUrl, client),
        apiKey: 'key',
      );

      final vector = (await provider.embed('hello')).unwrap();

      expect(vector, [0.1, 0.25]);
    });
  });

  group('Anthropic provider', () {
    test('стримит content_block_delta и usage', () async {
      late http.Request captured;
      final client = MockClient.streaming((request, bodyStream) async {
        captured = request as http.Request;
        await bodyStream.drain<void>();
        return _sse(
          'event: message_start\n'
          'data: {"type":"message_start","message":{"usage":'
          '{"input_tokens":7,"output_tokens":0}}}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,'
          '"delta":{"type":"text_delta","text":"Hello"}}\n\n'
          'event: message_delta\n'
          'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
          '"usage":{"output_tokens":4}}\n\n'
          'event: message_stop\n'
          'data: {"type":"message_stop"}\n\n',
          request: request,
        );
      });
      final config = _config(type: LlmProviderType.anthropic);
      final provider = AnthropicProvider(
        config,
        client: _api(config.baseUrl, client),
        apiKey: 'anthropic-secret',
      );

      final response = (await provider.complete(_request())).unwrap();

      expect(response.content, 'Hello');
      expect(response.usage.promptTokens, 7);
      expect(response.usage.completionTokens, 4);
      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'anthropic-secret');
      expect(captured.headers['anthropic-version'], '2023-06-01');
    });
  });

  group('Google provider', () {
    test('стримит candidates и usageMetadata', () async {
      late http.Request captured;
      final client = MockClient.streaming((request, bodyStream) async {
        captured = request as http.Request;
        await bodyStream.drain<void>();
        return _sse(
          'data: {"candidates":[{"content":{"parts":[{"text":"Gemini"}]},'
          '"finishReason":"STOP"}],"usageMetadata":'
          '{"promptTokenCount":2,"candidatesTokenCount":3,'
          '"totalTokenCount":5}}\n\n',
          request: request,
        );
      });
      final config = _config(type: LlmProviderType.google);
      final provider = GoogleProvider(
        config,
        client: _api(config.baseUrl, client),
        apiKey: 'google-secret',
      );

      final response = (await provider.complete(_request())).unwrap();

      expect(response.content, 'Gemini');
      expect(response.usage.promptTokens, 2);
      expect(response.usage.completionTokens, 3);
      expect(
        captured.url.path,
        contains('test-model:streamGenerateContent'),
      );
      expect(captured.url.queryParameters['alt'], 'sse');
      expect(captured.headers['x-goog-api-key'], 'google-secret');
    });
  });
}
