import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/llm_config_repository.dart';
import 'package:second_brain/features/learning/application/learning_trainer.dart';
import 'package:second_brain/features/learning/domain/learning_track.dart';
import 'package:second_brain/features/llm/data/llm_provider_factory.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';

import 'helpers/in_memory_db.dart';

String _sseText(String text) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': text},
        },
      ],
    })}\n\n'
    'data: [DONE]\n\n';

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late LlmProviderConfig config;

  setUp(() async {
    db = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
    config = (await DriftLlmConfigRepository(db, secrets).create(
      const LlmConfigDraft(
        type: LlmProviderType.openai,
        displayName: 'Test',
        baseUrl: 'https://api.test/v1',
        model: 'test-model',
        maxTokens: 2048,
        apiKey: 'key',
      ),
    )).unwrap();
  });

  LearningTrainer trainer(
    http.Client client, {
    List<LlmProviderConfig>? configs,
  }) => LearningTrainer(
    configs: configs ?? [config],
    configRepo: DriftLlmConfigRepository(db, secrets),
    factory: LlmProviderFactory(client: client, retryDelay: (_) async {}),
  );

  test('генерирует roadmap из JSON в markdown-блоке', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            _sseText(
              '```json\n'
              '[{"title":"Основы","description":"Синтаксис"},'
              '{"title":"Практика","description":"Мини-проект"}]\n'
              '```',
            ),
          ),
        ),
        200,
        request: request,
      );
    });

    final result = await trainer(client).generateRoadmap('Dart');

    final steps = (result as Success<List<LearningStep>>).value;
    expect(steps, hasLength(2));
    expect(steps.first.title, 'Основы');
    expect(steps.last.description, 'Мини-проект');
    expect(steps.first.id, isNotEmpty);
  });

  test('не отправляет приватный трек в LLM', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 500);
    });
    final track = LearningTrack(
      id: 1,
      title: 'Private',
      goal: 'secret',
      steps: const [],
      customFields: const {},
      isPrivateForLlm: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

    final result = await trainer(client).suggestMaterials(track);

    expect(result, isA<Failure<String>>());
    expect(called, isFalse);
  });

  test('без конфигурации возвращает ошибку без сети', () async {
    final client = MockClient((request) async {
      fail('сеть не должна вызываться');
    });

    final result = await trainer(
      client,
      configs: const [],
    ).generateRoadmap('Цель');

    expect(result, isA<Failure<List<LearningStep>>>());
  });

  test('предлагает материалы и задаёт вопросы', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode(_sseText('Материал и вопрос'))),
        200,
        request: request,
      );
    });
    final track = LearningTrack(
      id: 1,
      title: 'Dart',
      goal: 'Писать приложения',
      steps: const [
        LearningStep(
          id: 's1',
          title: 'Основы',
          status: LearningStepStatus.done,
        ),
      ],
      customFields: const {},
      isPrivateForLlm: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

    final materials = await trainer(client).suggestMaterials(track);
    final checkIn = await trainer(client).checkIn(track);

    expect((materials as Success<String>).value, contains('Материал'));
    expect((checkIn as Success<String>).value, contains('вопрос'));
  });
}
