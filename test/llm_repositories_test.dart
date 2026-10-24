import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' as db;
import 'package:second_brain/data/repositories/chat_repository.dart';
import 'package:second_brain/data/repositories/llm_config_repository.dart';
import 'package:second_brain/features/chat/domain/chat_message.dart';
import 'package:second_brain/features/chat/domain/chat_thread.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';

import 'helpers/in_memory_db.dart';

void main() {
  group('LlmConfigRepository', () {
    late db.AppDatabase database;
    late InMemorySecretStore secrets;
    late DriftLlmConfigRepository repository;

    setUp(() {
      database = InMemoryDbFactory.open();
      secrets = InMemorySecretStore();
      repository = DriftLlmConfigRepository(database, secrets);
    });

    tearDown(() async {
      await secrets.clear();
      await database.close();
    });

    test('ключ хранится только в SecretStore, в БД — secretRef', () async {
      final config = (await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.openai,
          displayName: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
          apiKey: 'sk-live-secret',
        ),
      )).unwrap();

      expect(config.isDefault, isTrue);
      expect(config.maxTokens, 1024);
      expect(
        (await secrets.read(config.secretRef)).unwrap(),
        'sk-live-secret',
      );

      final row = await database.select(database.llmProviderConfigs).getSingle();
      expect(row.secretRef, config.secretRef);
      expect(row.secretRef, isNot('sk-live-secret'));
      expect(row.providerType, 'openai');
      expect(row.maxTokens, 1024);
      expect(secrets.debugValues.values, contains('sk-live-secret'));
    });

    test('setDefault переключает единственного провайдера по умолчанию', () async {
      final first = (await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.openai,
          displayName: 'First',
          baseUrl: 'https://api.test/v1',
          model: 'first',
        ),
      )).unwrap();
      final second = (await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.anthropic,
          displayName: 'Second',
          baseUrl: 'https://api.anthropic.com/v1',
          model: 'second',
        ),
      )).unwrap();
      expect(second.isDefault, isFalse);

      (await repository.setDefault(second.id)).unwrap();

      final items = (await repository.list()).unwrap();
      expect(items.where((item) => item.isDefault), hasLength(1));
      expect(items.singleWhere((item) => item.isDefault).id, second.id);
      expect(items.singleWhere((item) => item.id == first.id).isDefault, isFalse);
      expect((await repository.getDefault()).unwrap()?.id, second.id);
    });

    test('update меняет key, maxTokens и удаляет key пустой строкой', () async {
      final config = (await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.openai,
          displayName: 'OpenAI',
          baseUrl: 'https://api.test/v1',
          model: 'old-model',
          apiKey: 'old-key',
        ),
      )).unwrap();

      final updated = (await repository.update(
        config.id,
        const LlmConfigDraft(
          type: LlmProviderType.openaiCompatible,
          displayName: 'Local',
          baseUrl: 'http://localhost:11434/v1',
          model: 'llama3.1',
          maxTokens: 4096,
          apiKey: 'new-key',
        ),
      )).unwrap();
      expect(updated.type, LlmProviderType.openaiCompatible);
      expect(updated.model, 'llama3.1');
      expect(updated.maxTokens, 4096);
      expect((await repository.readApiKey(config.id)).unwrap(), 'new-key');

      final cleared = (await repository.update(
        config.id,
        LlmConfigDraft(
          type: updated.type,
          displayName: updated.displayName,
          baseUrl: updated.baseUrl,
          model: updated.model,
          maxTokens: updated.maxTokens,
          apiKey: '',
        ),
      )).unwrap();
      expect(cleared.maxTokens, 4096);
      expect((await repository.readApiKey(config.id)).unwrap(), isNull);
    });

    test('валидация baseUrl и лимита токенов не пишет в БД', () async {
      final badUrl = await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.openai,
          displayName: 'Bad',
          baseUrl: 'ftp://example.com',
          model: 'model',
        ),
      );
      final badTokens = await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.openai,
          displayName: 'Bad',
          baseUrl: 'https://api.test/v1',
          model: 'model',
          maxTokens: 0,
        ),
      );

      expect(badUrl, isA<Failure<LlmProviderConfig>>());
      expect(badTokens, isA<Failure<LlmProviderConfig>>());
      expect(await database.select(database.llmProviderConfigs).get(), isEmpty);
    });

    test('delete удаляет key и обнуляет providerConfigId у треда', () async {
      final config = (await repository.create(
        const LlmConfigDraft(
          type: LlmProviderType.openai,
          displayName: 'OpenAI',
          baseUrl: 'https://api.test/v1',
          model: 'model',
          apiKey: 'secret',
        ),
      )).unwrap();
      final chats = DriftChatRepository(database);
      final thread = (await chats.createThread(
        ChatThreadDraft(
          title: 'Thread',
          providerConfigId: config.id,
          model: config.model,
        ),
      )).unwrap();

      (await repository.delete(config.id)).unwrap();

      expect(await database.select(database.llmProviderConfigs).get(), isEmpty);
      expect(secrets.debugValues, isEmpty);
      expect((await chats.getThread(thread.id)).unwrap()?.providerConfigId, isNull);
    });
  });

  group('ChatRepository', () {
    late db.AppDatabase database;
    late DriftChatRepository repository;

    setUp(() {
      database = InMemoryDbFactory.open();
      repository = DriftChatRepository(database);
    });

    tearDown(() => database.close());

    test('создаёт тред, сохраняет сообщения и загружает историю', () async {
      final thread = (await repository.createThread(
        const ChatThreadDraft(
          title: 'Первый диалог',
          providerConfigId: null,
          model: 'test-model',
        ),
      )).unwrap();
      final user = (await repository.appendMessage(
        ChatMessageDraft(
          threadId: thread.id,
          role: LlmRole.user,
          content: 'Вопрос',
        ),
      )).unwrap();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final assistant = (await repository.appendMessage(
        ChatMessageDraft(
          threadId: thread.id,
          role: LlmRole.assistant,
          content: 'Ответ',
          promptTokens: 3,
          completionTokens: 5,
        ),
      )).unwrap();

      final messages = (await repository.listMessages(thread.id)).unwrap();
      expect(messages.map((message) => message.id), [user.id, assistant.id]);
      expect(messages.last.role, LlmRole.assistant);
      expect(messages.last.promptTokens, 3);
      expect(messages.last.completionTokens, 5);
      expect((await repository.listThreads()).unwrap(), hasLength(1));
    });

    test('rename обновляет заголовок и updatedAt', () async {
      final thread = (await repository.createThread(
        const ChatThreadDraft(
          title: 'Old',
          providerConfigId: null,
          model: 'model',
        ),
      )).unwrap();
      await Future<void>.delayed(const Duration(milliseconds: 2));

      final renamed = (await repository.renameThread(thread.id, 'New')).unwrap();

      expect(renamed.title, 'New');
      expect(renamed.updatedAt.isBefore(thread.updatedAt), isFalse);
    });

    test('delete треда каскадно удаляет сообщения', () async {
      final thread = (await repository.createThread(
        const ChatThreadDraft(
          title: 'Thread',
          providerConfigId: null,
          model: 'model',
        ),
      )).unwrap();
      await repository.appendMessage(
        ChatMessageDraft(
          threadId: thread.id,
          role: LlmRole.user,
          content: 'Текст',
        ),
      );

      (await repository.deleteThread(thread.id)).unwrap();

      expect(await database.select(database.chatThreads).get(), isEmpty);
      expect(await database.select(database.chatMessages).get(), isEmpty);
    });

    test('пустой заголовок и пустое сообщение отклоняются', () async {
      final thread = await repository.createThread(
        const ChatThreadDraft(
          title: '   ',
          providerConfigId: null,
          model: 'model',
        ),
      );
      expect(thread, isA<Failure<ChatThread>>());

      final saved = await repository.appendMessage(
        const ChatMessageDraft(
          threadId: 1,
          role: LlmRole.assistant,
          content: '',
        ),
      );
      expect(saved, isA<Failure<ChatMessage>>());
    });
  });
}
