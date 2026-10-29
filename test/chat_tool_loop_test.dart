import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' hide LlmProviderConfig;
import 'package:second_brain/data/repositories/llm_config_repository.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/tool_audit_repository.dart';
import 'package:second_brain/features/chat/application/chat_controller.dart';
import 'package:second_brain/features/llm/data/llm_provider_factory.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';
import 'package:second_brain/features/llm/tools/llm_tool_registry.dart';

import 'helpers/in_memory_db.dart';

/// SSE-ответ модели, который просит выполнить один create_note.
String _toolCallSse(String title) => _toolCallsSse([
  {
    'id': 'call_1',
    'name': 'create_note',
    'args': {'title': title},
  },
]);

/// SSE-ответ с несколькими tool calls в одном ответе модели.
String _toolCallsSse(List<Map<String, Object?>> calls) {
  final encoded = [
    for (var i = 0; i < calls.length; i++)
      {
        'index': i,
        'id': calls[i]['id'],
        'type': 'function',
        'function': {
          'name': calls[i]['name'],
          'arguments': jsonEncode(calls[i]['args']),
        },
      },
  ];
  return [
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'tool_calls': encoded},
        },
      ],
    })}\n\n',
    'data: ${jsonEncode({
      'choices': [
        {'delta': <String, Object?>{}, 'finish_reason': 'tool_calls'},
      ],
    })}\n\n',
    'data: [DONE]\n\n',
  ].join();
}

/// Инструмент, который зависает, пока тест не отпустит его.
final class _BlockingTool extends LlmToolBase {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  String get name => 'blocking_tool';

  @override
  String get description => 'Тестовый инструмент';

  @override
  Map<String, Object?> get parameters => {
    'type': 'object',
    'properties': {
      'value': {'type': 'string'},
    },
  };

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return Result.success({'id': 1});
  }
}

String _textSse(String text) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': text},
        },
      ],
    })}\n\n'
    'data: [DONE]\n\n';

/// Отдаёт ответы по очереди и запоминает тела запросов.
http.Client _scripted(List<String> responses, List<String> bodies) {
  var index = 0;
  return MockClient.streaming((request, bodyStream) async {
    bodies.add(await bodyStream.transform(utf8.decoder).join());
    final body =
        responses[index < responses.length ? index : responses.length - 1];
    index++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
    );
  });
}

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;

  setUp(() async {
    database = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(database.close);
    addTearDown(secrets.clear);
    await DriftLlmConfigRepository(database, secrets).create(
      const LlmConfigDraft(
        type: LlmProviderType.openai,
        displayName: 'Test OpenAI',
        baseUrl: 'https://api.test/v1',
        model: 'test-model',
        maxTokens: 512,
        apiKey: 'sk-test',
      ),
    );
  });

  ProviderContainer container(http.Client client) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => database),
        secretStoreProvider.overrideWithValue(secrets),
        llmProviderFactoryProvider.overrideWith(
          (ref) => LlmProviderFactory(client: client, retryDelay: (_) async {}),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'вызов инструмента создаёт заметку, пишет аудит и отдаёт финальный ответ',
    () async {
      final bodies = <String>[];
      final c = container(
        _scripted([_toolCallSse('Идея'), _textSse('Готово')], bodies),
      );
      await c.read(chatControllerProvider.future);
      final controller = c.read(chatControllerProvider.notifier);

      final accepted = await controller.sendMessage('Создай заметку Идея');
      await controller.waitForIdle();

      expect(accepted, isTrue);
      final state = c.read(chatControllerProvider).value!;
      expect(state.errorCode, isNull);
      expect(state.isStreaming, isFalse);
      expect(state.messages.last.content, 'Готово');
      expect(
        state.messages,
        hasLength(2),
        reason: 'tool-сообщения не в истории',
      );

      final notes = (await DriftNotesRepository(database).list()).unwrap();
      expect(notes.map((note) => note.title), ['Идея']);

      final audit = (await DriftToolAuditRepository(
        database,
      ).listRecent()).unwrap();
      expect(audit.single.toolName, 'create_note');
      expect(audit.single.status, ToolAuditStatus.ok);

      expect(bodies, hasLength(2));
      final secondMessages =
          (jsonDecode(bodies[1]) as Map<String, Object?>)['messages']!
              as List<Object?>;
      final toolMessage = secondMessages
          .cast<Map<String, Object?>>()
          .firstWhere((message) => message['role'] == 'tool');
      expect(toolMessage['tool_call_id'], 'call_1');
      expect(toolMessage['content'], contains('"ok":true'));
    },
  );

  test('модель, которая зовёт инструменты бесконечно, получает llm_error '
      'после лимита раундов', () async {
    final bodies = <String>[];
    final c = container(
      _scripted([
        _toolCallSse('A'),
        _toolCallSse('B'),
        _toolCallSse('C'),
        _toolCallSse('D'),
      ], bodies),
    );
    await c.read(chatControllerProvider.future);
    final controller = c.read(chatControllerProvider.notifier);

    await controller.sendMessage('Цикл');
    await controller.waitForIdle();

    final state = c.read(chatControllerProvider).value!;
    expect(state.errorCode, 'llm_error');
    expect(state.isStreaming, isFalse);
    expect(bodies, hasLength(maxToolRounds + 1));

    final notes = (await DriftNotesRepository(database).list()).unwrap();
    expect(
      notes.map((note) => note.title),
      unorderedEquals(['A', 'B', 'C']),
      reason: 'четвёртый вызов не выполняется',
    );
  });

  test('несколько tool calls в одном ответе выполняются оба', () async {
    final bodies = <String>[];
    final c = container(
      _scripted([
        _toolCallsSse([
          {
            'id': 'call_1',
            'name': 'create_note',
            'args': {'title': 'Первая'},
          },
          {
            'id': 'call_2',
            'name': 'create_note',
            'args': {'title': 'Вторая'},
          },
        ]),
        _textSse('Обе готовы'),
      ], bodies),
    );
    await c.read(chatControllerProvider.future);
    final controller = c.read(chatControllerProvider.notifier);

    await controller.sendMessage('Создай две заметки');
    await controller.waitForIdle();

    final state = c.read(chatControllerProvider).value!;
    expect(state.errorCode, isNull);
    expect(state.messages.last.content, 'Обе готовы');

    final notes = (await DriftNotesRepository(database).list()).unwrap();
    expect(
      notes.map((note) => note.title),
      unorderedEquals(['Первая', 'Вторая']),
    );

    final audit = (await DriftToolAuditRepository(
      database,
    ).listRecent()).unwrap();
    expect(audit, hasLength(2));
    expect(audit.every((entry) => entry.status == ToolAuditStatus.ok), isTrue);

    final secondMessages =
        (jsonDecode(bodies[1]) as Map<String, Object?>)['messages']!
            as List<Object?>;
    final toolMessages = secondMessages
        .cast<Map<String, Object?>>()
        .where((message) => message['role'] == 'tool')
        .toList();
    expect(toolMessages, hasLength(2));
    expect(toolMessages.map((message) => message['tool_call_id']), [
      'call_1',
      'call_2',
    ]);
  });

  test('отмена во время выполнения инструмента не запускает следующий раунд '
      'и не пишет в историю лишнее', () async {
    final bodies = <String>[];
    final tool = _BlockingTool();
    final registry = LlmToolRegistry()..register(tool);
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => database),
        secretStoreProvider.overrideWithValue(secrets),
        llmProviderFactoryProvider.overrideWith(
          (ref) => LlmProviderFactory(
            client: _scripted([
              _toolCallsSse([
                {
                  'id': 'call_1',
                  'name': 'blocking_tool',
                  'args': {'value': 'x'},
                },
              ]),
              _textSse('Не должно выполниться'),
            ], bodies),
            retryDelay: (_) async {},
          ),
        ),
        llmToolRegistryProvider.overrideWith((ref) async => registry),
      ],
    );
    addTearDown(c.dispose);
    await c.read(chatControllerProvider.future);
    final controller = c.read(chatControllerProvider.notifier);

    await controller.sendMessage('Запусти инструмент');
    await tool.started.future;
    await controller.cancel();
    tool.release.complete();
    // Даём циклу инструментов увидеть отмену и завершиться.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bodies, hasLength(1), reason: 'второй раунд не должен стартовать');
    final state = c.read(chatControllerProvider).value!;
    expect(state.isStreaming, isFalse);
    expect(state.errorCode, 'cancelled');
    expect(state.messages, hasLength(2));
  });
}
