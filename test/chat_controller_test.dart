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
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/features/chat/application/chat_controller.dart';
import 'package:second_brain/features/llm/application/llm_config_controller.dart';
import 'package:second_brain/features/llm/application/llm_context_loader.dart';
import 'package:second_brain/features/llm/data/llm_provider_factory.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';
import 'package:second_brain/features/notes/domain/note.dart';

import 'helpers/in_memory_db.dart';

const _sseText =
    'data: {"choices":[{"delta":{"content":"Привет"}}]}\n\n'
    'data: {"choices":[{"delta":{"content":"!"}}],'
    '"usage":{"prompt_tokens":3,"completion_tokens":2}}\n\n'
    'data: [DONE]\n\n';

const _ssePartial = 'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n';

ProviderContainer _container({
  required AppDatabase database,
  required InMemorySecretStore secrets,
  required http.Client client,
}) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith((ref) async => database),
    secretStoreProvider.overrideWithValue(secrets),
    llmProviderFactoryProvider.overrideWith(
      (ref) => LlmProviderFactory(client: client, retryDelay: (_) async {}),
    ),
  ],
);

http.Client _successClient(List<String> bodies) =>
    MockClient.streaming((request, bodyStream) async {
      bodies.add(await bodyStream.transform(utf8.decoder).join());
      return http.StreamedResponse(
        Stream.value(utf8.encode(_sseText)),
        200,
        request: request,
      );
    });

List<Map<String, Object?>> _requestMessages(String body) {
  final payload = jsonDecode(body) as Map<String, Object?>;
  return (payload['messages'] as List<Object?>).cast<Map<String, Object?>>();
}

String _lastRequestText(String body) {
  final messages = _requestMessages(body);
  return messages.last['content']! as String;
}

Future<void> _waitForStreamingText(
  ProviderContainer container,
  String text,
) async {
  for (var i = 0; i < 400; i++) {
    final state = container.read(chatControllerProvider).value;
    if (state?.streamingText == text) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Не дождались streamingText="$text"');
}

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

  test(
    'sendMessage стримит ответ, сохраняет историю и лимит токенов',
    () async {
      final bodies = <String>[];
      final client = _successClient(bodies);
      final container = _container(
        database: database,
        secrets: secrets,
        client: client,
      );
      addTearDown(container.dispose);
      await container.read(chatControllerProvider.future);
      final controller = container.read(chatControllerProvider.notifier);

      final accepted = await controller.sendMessage('Привет, ассистент');
      await controller.waitForIdle();

      expect(accepted, isTrue);
      final state = container.read(chatControllerProvider).value!;
      expect(state.isStreaming, isFalse);
      expect(state.errorCode, isNull);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.role.dbValue, 'user');
      expect(state.messages.last.role.dbValue, 'assistant');
      expect(state.messages.last.content, 'Привет!');
      expect(state.messages.last.promptTokens, 3);
      expect(state.messages.last.completionTokens, 2);
      expect(state.threads, hasLength(1));

      final payload = jsonDecode(bodies.single) as Map<String, Object?>;
      expect(payload['model'], 'test-model');
      expect(payload['max_tokens'], 512);
      expect(_lastRequestText(bodies.single), 'Привет, ассистент');

      final stored = (await DriftChatRepository(
        database,
      ).listMessages(state.activeThreadId!)).unwrap();
      expect(stored, hasLength(2));
    },
  );

  test(
    'приватность контекста читается из БД, а не из вызывающего кода',
    () async {
      final notes = DriftNotesRepository(database);
      final publicNote = (await notes.create(
        const NoteDraft(title: 'Public title', body: 'public body'),
      )).unwrap();
      final privateNote = (await notes.create(
        const NoteDraft(
          title: 'Private title',
          body: 'private body',
          isPrivateForLlm: true,
        ),
      )).unwrap();
      final bodies = <String>[];
      final container = _container(
        database: database,
        secrets: secrets,
        client: _successClient(bodies),
      );
      addTearDown(container.dispose);
      await container.read(chatControllerProvider.future);

      final accepted = await container
          .read(chatControllerProvider.notifier)
          .sendMessage(
            'Вопрос',
            contextRefs: [
              LlmContextRef(LlmContextEntityType.note, publicNote.id),
              LlmContextRef(LlmContextEntityType.note, privateNote.id),
            ],
          );
      await container.read(chatControllerProvider.notifier).waitForIdle();

      expect(accepted, isTrue);
      final content = _lastRequestText(bodies.single);
      expect(content, contains('Public title'));
      expect(content, contains('public body'));
      expect(content, isNot(contains('Private title')));
      expect(content, isNot(contains('private body')));
    },
  );

  test('cancel останавливает поток и сохраняет полученный фрагмент', () async {
    final bodyController = StreamController<List<int>>();
    addTearDown(() async {
      if (!bodyController.isClosed) await bodyController.close();
    });
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
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

    expect(await controller.sendMessage('Долгий ответ'), isTrue);
    bodyController.add(utf8.encode(_ssePartial));
    await _waitForStreamingText(container, 'partial');

    await controller.cancel();
    await controller.waitForIdle();

    final state = container.read(chatControllerProvider).value!;
    expect(state.isStreaming, isFalse);
    expect(state.streamingText, isEmpty);
    expect(state.messages.last.content, 'partial');
    expect(state.messages.last.errorCode, isNull);
  });

  test('ошибка провайдера сохраняет маркер и не блокирует отправку', () async {
    var calls = 0;
    final bodies = <String>[];
    final client = MockClient.streaming((request, bodyStream) async {
      calls++;
      bodies.add(await bodyStream.transform(utf8.decoder).join());
      if (calls == 1) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('provider failure')),
          401,
          request: request,
        );
      }
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

    expect(await controller.sendMessage('Ошибка'), isTrue);
    await controller.waitForIdle();
    var state = container.read(chatControllerProvider).value!;
    expect(state.isStreaming, isFalse);
    expect(state.errorCode, 'llm_error');
    expect(state.messages.last.errorCode, 'llm_error');

    // S03-001: следующая отправка не блокируется старым errorCode.
    expect(await controller.sendMessage('После ошибки'), isTrue);
    await controller.waitForIdle();
    state = container.read(chatControllerProvider).value!;
    expect(state.errorCode, isNull);
    expect(state.messages.last.content, 'Привет!');
    expect(calls, 2);
    // User-сообщения склеиваются, поэтому в запрос попадают оба текста.
    expect(_lastRequestText(bodies.last), 'Ошибка\n\nПосле ошибки');
  });

  test('retryLast повторяет запрос без partial-ответа с ошибкой', () async {
    var calls = 0;
    final bodies = <String>[];
    final client = MockClient.streaming((request, bodyStream) async {
      calls++;
      bodies.add(await bodyStream.transform(utf8.decoder).join());
      if (calls == 1) {
        Stream<List<int>> failing() async* {
          yield utf8.encode(_ssePartial);
          throw http.ClientException('stream failed');
        }

        return http.StreamedResponse(failing(), 200, request: request);
      }
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

    expect(await controller.sendMessage('Хрупкий запрос'), isTrue);
    await controller.waitForIdle();
    var state = container.read(chatControllerProvider).value!;
    expect(state.errorCode, 'llm_error');
    expect(state.messages.last.content, 'partial');
    expect(state.messages.last.errorCode, 'llm_error');

    expect(await controller.retryLast(), isTrue);
    await controller.waitForIdle();
    state = container.read(chatControllerProvider).value!;
    expect(state.errorCode, isNull);
    expect(state.messages.last.content, 'Привет!');

    final retried = _requestMessages(bodies.last);
    expect(
      retried.map((message) => message['content']),
      isNot(contains('partial')),
    );
    expect(retried, hasLength(1));
    expect(retried.single['content'], 'Хрупкий запрос');
  });

  test('синхронный guard отклоняет параллельный sendMessage', () async {
    final bodyController = StreamController<List<int>>();
    addTearDown(() async {
      if (!bodyController.isClosed) await bodyController.close();
    });
    var calls = 0;
    final client = MockClient.streaming((request, bodyStream) async {
      calls++;
      await bodyStream.drain<void>();
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

    expect(await controller.sendMessage('Первый'), isTrue);
    expect(await controller.sendMessage('Второй'), isFalse);
    expect(calls, 1);

    bodyController.add(utf8.encode(_sseText));
    await bodyController.close();
    await controller.waitForIdle();
    final state = container.read(chatControllerProvider).value!;
    expect(state.messages.map((message) => message.content), [
      'Первый',
      'Привет!',
    ]);
  });

  test(
    'создание нового треда во время streaming отменяет старый запрос',
    () async {
      final bodyController = StreamController<List<int>>();
      addTearDown(() async {
        if (!bodyController.isClosed) await bodyController.close();
      });
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.drain<void>();
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

      expect(await controller.sendMessage('Долгий старый тред'), isTrue);
      bodyController.add(utf8.encode(_ssePartial));
      await _waitForStreamingText(container, 'partial');
      final oldThreadId = container
          .read(chatControllerProvider)
          .value!
          .activeThreadId!;

      expect(await controller.createThread('Новый тред'), isTrue);
      final state = container.read(chatControllerProvider).value!;
      expect(state.threads, hasLength(2));
      expect(state.activeThreadId, isNot(oldThreadId));
      expect(state.messages, isEmpty);
      expect(state.isStreaming, isFalse);

      final oldMessages = (await DriftChatRepository(
        database,
      ).listMessages(oldThreadId)).unwrap();
      expect(oldMessages.map((message) => message.content), [
        'Долгий старый тред',
        'partial',
      ]);

      // Завершение отменённого потока не должно подменить новый тред.
      bodyController.add(utf8.encode(_sseText));
      await bodyController.close();
      await controller.waitForIdle();
      final after = container.read(chatControllerProvider).value!;
      expect(after.activeThreadId, state.activeThreadId);
      expect(after.messages, isEmpty);
    },
  );

  test('fallback на default-провайдера использует его модель', () async {
    final bodies = <String>[];
    final container = _container(
      database: database,
      secrets: secrets,
      client: _successClient(bodies),
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);
    final controller = container.read(chatControllerProvider.notifier);
    final configController = container.read(
      llmConfigControllerProvider.notifier,
    );

    expect(await controller.createThread('Старый провайдер'), isTrue);
    expect(await configController.delete(config.id), isTrue);
    expect(
      await configController.create(
        const LlmConfigDraft(
          type: LlmProviderType.openaiCompatible,
          displayName: 'Local fallback',
          baseUrl: 'http://localhost:11434/v1',
          model: 'new-model',
          apiKey: 'local-key',
        ),
      ),
      isTrue,
    );

    expect(await controller.sendMessage('После удаления'), isTrue);
    await controller.waitForIdle();

    final payload = jsonDecode(bodies.single) as Map<String, Object?>;
    expect(payload['model'], 'new-model');
  });

  test('приватное сообщение не попадает в следующий запрос', () async {
    final bodies = <String>[];
    final container = _container(
      database: database,
      secrets: secrets,
      client: _successClient(bodies),
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);
    final controller = container.read(chatControllerProvider.notifier);

    expect(await controller.sendMessage('secret question'), isTrue);
    await controller.waitForIdle();
    final firstUser = container
        .read(chatControllerProvider)
        .value!
        .messages
        .first;
    expect(await controller.setMessagePrivate(firstUser.id, true), isTrue);

    expect(await controller.sendMessage('normal question'), isTrue);
    await controller.waitForIdle();

    final retried = _requestMessages(bodies.last);
    expect(retried, hasLength(1));
    expect(retried.single['content'], 'normal question');
  });

  test(
    'без API-ключа запрос не уходит и возвращается api_key_missing',
    () async {
      final bodies = <String>[];
      var networkCalls = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        networkCalls++;
        bodies.add(await bodyStream.transform(utf8.decoder).join());
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
      await secrets.delete(config.secretRef);

      final accepted = await container
          .read(chatControllerProvider.notifier)
          .sendMessage('Нет ключа');
      await container.read(chatControllerProvider.notifier).waitForIdle();

      expect(accepted, isFalse);
      expect(networkCalls, 0);
      expect(bodies, isEmpty);
      final state = container.read(chatControllerProvider).value!;
      expect(state.errorCode, 'api_key_missing');
      expect(state.messages, isEmpty);
    },
  );

  test('история восстанавливается из БД без сетевого запроса', () async {
    final bodies = <String>[];
    final first = _container(
      database: database,
      secrets: secrets,
      client: _successClient(bodies),
    );
    await first.read(chatControllerProvider.future);
    final firstController = first.read(chatControllerProvider.notifier);
    expect(await firstController.sendMessage('Сохрани меня'), isTrue);
    await firstController.waitForIdle();
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
