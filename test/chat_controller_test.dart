import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' hide LlmProviderConfig;
import 'package:second_brain/data/repositories/chat_repository.dart';
import 'package:second_brain/data/repositories/llm_config_repository.dart';
import 'package:second_brain/features/chat/application/chat_controller.dart';
import 'package:second_brain/features/llm/application/privacy_guard.dart';
import 'package:second_brain/features/llm/data/llm_provider_factory.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';

import 'helpers/in_memory_db.dart';

const _sseText =
    'data: {"choices":[{"delta":{"content":"Привет"}}]}\n\n'
    'data: {"choices":[{"delta":{"content":"!"}}],'
    '"usage":{"prompt_tokens":3,"completion_tokens":2}}\n\n'
    'data: [DONE]\n\n';

ProviderContainer _container({
  required AppDatabase database,
  required InMemorySecretStore secrets,
  required http.Client client,
}) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith((ref) async => database),
    secretStoreProvider.overrideWithValue(secrets),
    llmProviderFactoryProvider.overrideWith(
      (ref) => LlmProviderFactory(
        client: client,
        retryDelay: (_) async {},
      ),
    ),
  ],
);

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;
  late LlmProviderConfig config;

  setUp(() async {
    database = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(database.close);
    addTearDown(secrets.clear);
    config = (await DriftLlmConfigRepository(database, secrets).create(
      const LlmConfigDraft(
        type: LlmProviderType.openai,
        displayName: 'Test OpenAI',
        baseUrl: 'https://api.test/v1',
        model: 'test-model',
        maxTokens: 512,
        apiKey: 'sk-test',
      ),
    )).unwrap();
  });

  test('sendMessage стримит ответ, сохраняет историю и лимит токенов', () async {
    late String body;
    final client = MockClient.streaming((request, bodyStream) async {
      body = await bodyStream.transform(utf8.decoder).join();
      return http.StreamedResponse(
        Stream.value(utf8.encode(_sseText)),
        200,
        request: request,
      );
    });
    final container = _container(
      database: database,
      secrets: secrets,
      client: client,
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);
    final controller = container.read(chatControllerProvider.notifier);

    await controller.sendMessage('Привет, ассистент');

    final state = container.read(chatControllerProvider).value!;
    expect(state.isStreaming, isFalse);
    expect(state.messages, hasLength(2));
    expect(state.messages.first.role.dbValue, 'user');
    expect(state.messages.last.role.dbValue, 'assistant');
    expect(state.messages.last.content, 'Привет!');
    expect(state.messages.last.promptTokens, 3);
    expect(state.messages.last.completionTokens, 2);
    expect(state.threads, hasLength(1));

    final payload = jsonDecode(body) as Map<String, Object?>;
    expect(payload['model'], 'test-model');
    expect(payload['max_tokens'], 512);
    final requestMessages = payload['messages'] as List<Object?>;
    expect(
      (requestMessages.last as Map<String, Object?>)['content'],
      'Привет, ассистент',
    );

    final stored = (await DriftChatRepository(
      database,
    ).listMessages(state.activeThreadId!)).unwrap();
    expect(stored, hasLength(2));
  });

  test('приватный контекст не попадает в запрос к LLM', () async {
    late String body;
    final client = MockClient.streaming((request, bodyStream) async {
      body = await bodyStream.transform(utf8.decoder).join();
      return http.StreamedResponse(
        Stream.value(utf8.encode(_sseText)),
        200,
        request: request,
      );
    });
    final container = _container(
      database: database,
      secrets: secrets,
      client: client,
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);

    await container
        .read(chatControllerProvider.notifier)
        .sendMessage(
          'Вопрос',
          context: const [
            LlmContextItem(
              entityType: 'note',
              entityId: 1,
              title: 'Public title',
              body: 'public body',
              isPrivateForLlm: false,
            ),
            LlmContextItem(
              entityType: 'note',
              entityId: 2,
              title: 'Private title',
              body: 'private body',
              isPrivateForLlm: true,
            ),
          ],
        );

    final payload = jsonDecode(body) as Map<String, Object?>;
    final requestMessages = payload['messages'] as List<Object?>;
    final content =
        (requestMessages.last as Map<String, Object?>)['content'] as String;
    expect(content, contains('Public title'));
    expect(content, contains('public body'));
    expect(content, isNot(contains('Private title')));
    expect(content, isNot(contains('private body')));
  });

  test('cancel останавливает поток и сохраняет полученный фрагмент', () async {
    final bodyController = StreamController<List<int>>();
    addTearDown(bodyController.close);
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      bodyController.add(
        utf8.encode(
          'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
        ),
      );
      return http.StreamedResponse(
        bodyController.stream,
        200,
        request: request,
      );
    });
    final container = _container(
      database: database,
      secrets: secrets,
      client: client,
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);
    final controller = container.read(chatControllerProvider.notifier);

    final send = controller.sendMessage('Долгий ответ');
    for (var i = 0; i < 200; i++) {
      final state = container.read(chatControllerProvider).value;
      if (state?.streamingText == 'partial') break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      container.read(chatControllerProvider).value?.streamingText,
      'partial',
    );

    await controller.cancel();
    await send;

    final state = container.read(chatControllerProvider).value!;
    expect(state.isStreaming, isFalse);
    expect(state.streamingText, isEmpty);
    expect(state.messages.last.content, 'partial');
    expect(state.messages.last.errorCode, isNull);
  });

  test('ошибка провайдера сохраняет маркер и не оставляет streaming', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode('provider failure')),
        500,
        request: request,
      );
    });
    final container = _container(
      database: database,
      secrets: secrets,
      client: client,
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);

    await container
        .read(chatControllerProvider.notifier)
        .sendMessage('Ошибка');

    final state = container.read(chatControllerProvider).value!;
    expect(state.isStreaming, isFalse);
    expect(state.errorCode, 'llm_error');
    expect(state.messages.last.errorCode, 'llm_error');
    expect(state.messages.last.content, isEmpty);
  });

  test('история восстанавливается из БД без сетевого запроса', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode(_sseText)),
        200,
        request: request,
      );
    });
    final first = _container(
      database: database,
      secrets: secrets,
      client: client,
    );
    await first.read(chatControllerProvider.future);
    await first
        .read(chatControllerProvider.notifier)
        .sendMessage('Сохрани меня');
    await first.read(chatControllerProvider.future);
    first.dispose();

    final offline = _container(
      database: database,
      secrets: secrets,
      client: MockClient((request) async {
        fail('Сеть не должна использоваться при загрузке истории');
      }),
    );
    addTearDown(offline.dispose);
    final state = await offline.read(chatControllerProvider.future);

    expect(state.threads, hasLength(1));
    expect(state.messages, hasLength(2));
    expect(state.messages.first.content, 'Сохрани меня');
    expect(state.messages.last.content, 'Привет!');
    expect(state.activeThreadId, state.threads.single.id);
    expect(config.id, state.threads.single.providerConfigId);
  });
}
