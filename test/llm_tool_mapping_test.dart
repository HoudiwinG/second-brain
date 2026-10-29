import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/network/api_client.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/features/llm/data/anthropic_provider.dart';
import 'package:second_brain/features/llm/data/google_provider.dart';
import 'package:second_brain/features/llm/domain/llm_chat.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';
import 'package:second_brain/features/llm/domain/llm_tool.dart';

LlmProviderConfig _config(LlmProviderType type) => LlmProviderConfig(
  id: 1,
  type: type,
  displayName: 'Test',
  baseUrl: type.defaultBaseUrl,
  model: 'test-model',
  maxTokens: 256,
  secretRef: 'llm.api_key.test',
  isDefault: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

ApiClient _api(String baseUrl, http.Client client) => ApiClient(
  baseUrl: baseUrl,
  client: client,
  maxRetries: 1,
  delay: (_) async {},
);

/// Историю диалога с вызовом инструмента и его результатом.
const _history = [
  LlmMessage(role: LlmRole.user, content: 'Создай заметку'),
  LlmMessage(
    role: LlmRole.assistant,
    content: '',
    toolCalls: [
      LlmToolCall(
        id: 'toolu_1',
        name: 'create_note',
        argumentsJson: '{"title":"X"}',
      ),
    ],
  ),
  LlmMessage(
    role: LlmRole.tool,
    name: 'create_note',
    toolCallId: 'toolu_1',
    content: '{"ok":true}',
  ),
];

void main() {
  test('Anthropic: вызов уходит tool_use, результат — tool_result', () async {
    String? capturedBody;
    final client = MockClient.streaming((request, bodyStream) async {
      capturedBody = await bodyStream.transform(utf8.decoder).join();
      return http.StreamedResponse(
        Stream.value(utf8.encode('data: {"type":"message_stop"}\n\n')),
        200,
        request: request,
      );
    });
    final provider = AnthropicProvider(
      _config(LlmProviderType.anthropic),
      client: _api(_config(LlmProviderType.anthropic).baseUrl, client),
      apiKey: 'key',
    );

    await provider.complete(
      const LlmChatRequest(model: 'test-model', messages: _history),
    );

    final messages =
        (jsonDecode(capturedBody!) as Map<String, Object?>)['messages']!
            as List<Object?>;
    final assistant = messages[1] as Map<String, Object?>;
    expect(assistant['role'], 'assistant');
    final toolUse =
        (assistant['content']! as List<Object?>).single as Map<String, Object?>;
    expect(toolUse['type'], 'tool_use');
    expect(toolUse['id'], 'toolu_1');
    expect(toolUse['input'], {'title': 'X'});

    final result = messages[2] as Map<String, Object?>;
    expect(result['role'], 'user');
    final toolResult =
        (result['content']! as List<Object?>).single as Map<String, Object?>;
    expect(toolResult['type'], 'tool_result');
    expect(toolResult['tool_use_id'], 'toolu_1');
  });

  test('Google: functionCall и functionResponse в contents', () async {
    String? capturedBody;
    final client = MockClient.streaming((request, bodyStream) async {
      capturedBody = await bodyStream.transform(utf8.decoder).join();
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"candidates":[{"finishReason":"STOP",'
            '"content":{"parts":[{"text":"ok"}]}}]}\n\n',
          ),
        ),
        200,
        request: request,
      );
    });
    final provider = GoogleProvider(
      _config(LlmProviderType.google),
      client: _api(_config(LlmProviderType.google).baseUrl, client),
      apiKey: 'key',
    );

    await provider.complete(
      const LlmChatRequest(model: 'test-model', messages: _history),
    );

    final contents =
        (jsonDecode(capturedBody!) as Map<String, Object?>)['contents']!
            as List<Object?>;
    final model = contents[1] as Map<String, Object?>;
    expect(model['role'], 'model');
    final call =
        (model['parts']! as List<Object?>).single as Map<String, Object?>;
    expect((call['functionCall']! as Map<String, Object?>)['args'], {
      'title': 'X',
    });

    final response = contents[2] as Map<String, Object?>;
    final part =
        (response['parts']! as List<Object?>).single as Map<String, Object?>;
    expect(
      (part['functionResponse']! as Map<String, Object?>)['name'],
      'create_note',
    );
  });

  test(
    'Google: результаты нескольких вызовов идут одним user-content',
    () async {
      String? capturedBody;
      final client = MockClient.streaming((request, bodyStream) async {
        capturedBody = await bodyStream.transform(utf8.decoder).join();
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: {"candidates":[]}\n\n')),
          200,
          request: request,
        );
      });
      final provider = GoogleProvider(
        _config(LlmProviderType.google),
        client: _api(_config(LlmProviderType.google).baseUrl, client),
        apiKey: 'key',
      );

      await provider.complete(
        const LlmChatRequest(
          model: 'test-model',
          messages: [
            LlmMessage(role: LlmRole.user, content: 'Заметку и задачу'),
            LlmMessage(
              role: LlmRole.assistant,
              content: '',
              toolCalls: [
                LlmToolCall(
                  id: 'call_1',
                  name: 'create_note',
                  argumentsJson: '{"title":"X"}',
                ),
                LlmToolCall(
                  id: 'call_2',
                  name: 'create_task',
                  argumentsJson: '{"title":"Y"}',
                ),
              ],
            ),
            LlmMessage(
              role: LlmRole.tool,
              name: 'create_note',
              toolCallId: 'call_1',
              content: '{"ok":true}',
            ),
            LlmMessage(
              role: LlmRole.tool,
              name: 'create_task',
              toolCallId: 'call_2',
              content: '{"ok":true}',
            ),
          ],
        ),
      );

      final contents =
          (jsonDecode(capturedBody!) as Map<String, Object?>)['contents']!
              as List<Object?>;
      expect(
        contents,
        hasLength(3),
        reason: 'два tool-результата не должны давать два user-content',
      );
      expect(contents.map((c) => (c! as Map<String, Object?>)['role']), [
        'user',
        'model',
        'user',
      ]);
      final results =
          (contents[2]! as Map<String, Object?>)['parts']! as List<Object?>;
      expect(results, hasLength(2));
      expect(
        results.map(
          (part) =>
              ((part! as Map<String, Object?>)['functionResponse']!
                  as Map<String, Object?>)['name'],
        ),
        ['create_note', 'create_task'],
      );
    },
  );

  test('Google: functionCall из ответа становится LlmToolCall', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      const body =
          'data: {"candidates":[{"content":{"parts":[{"functionCall":'
          '{"name":"create_note","args":{"title":"Y"}}}]},'
          '"finishReason":"STOP"}]}\n\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        request: request,
      );
    });
    final provider = GoogleProvider(
      _config(LlmProviderType.google),
      client: _api(_config(LlmProviderType.google).baseUrl, client),
      apiKey: 'key',
    );

    final result = await provider.complete(
      const LlmChatRequest(model: 'test-model', messages: _history),
    );

    final response = (result as Success<LlmResponse>).value;
    expect(response.toolCalls, hasLength(1));
    expect(response.toolCalls.single.name, 'create_note');
    expect(jsonDecode(response.toolCalls.single.argumentsJson), {'title': 'Y'});
  });
}
