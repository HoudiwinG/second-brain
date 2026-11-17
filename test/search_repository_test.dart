import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/repositories/chat_repository.dart';
import 'package:second_brain/data/repositories/finance_repository.dart';
import 'package:second_brain/data/repositories/ideas_repository.dart';
import 'package:second_brain/data/repositories/learning_repository.dart';
import 'package:second_brain/data/repositories/mail_repository.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/search_repository.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/data/search/search_index.dart';
import 'package:second_brain/features/chat/domain/chat_message.dart';
import 'package:second_brain/features/chat/domain/chat_thread.dart';
import 'package:second_brain/features/finance/domain/finance_transaction.dart';
import 'package:second_brain/features/ideas/domain/idea_entry.dart';
import 'package:second_brain/features/learning/domain/learning_track.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/search/domain/search_hit.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

void main() {
  group('FTS5 search', () {
    late AppDatabase db;
    late DriftNotesRepository notes;
    late DriftTasksRepository tasks;
    late DriftIdeasRepository ideas;
    late DriftFinanceRepository finance;
    late DriftSearchRepository search;

    setUp(() {
      db = InMemoryDbFactory.open();
      notes = DriftNotesRepository(db);
      tasks = DriftTasksRepository(db);
      ideas = DriftIdeasRepository(db);
      finance = DriftFinanceRepository(db);
      search = DriftSearchRepository(db);
    });
    tearDown(() => db.close());

    test('находит заметки, задачи, идеи и финансы, включая теги', () async {
      final note = (await notes.create(
        const NoteDraft(
          title: 'Flutter архитектура',
          body: 'Riverpod и Drift',
          tags: ['мобильная разработка'],
        ),
      )).unwrap();
      final task = (await tasks.create(
        const TaskDraft(
          title: 'Проверить FTS поиск',
          description: 'Проверить сниппеты и ранжирование',
          tags: ['backend'],
        ),
      )).unwrap();
      final idea = (await ideas.create(
        const IdeaDraft(text: 'Идея про поиск идей', tags: ['research']),
      )).unwrap();
      final money = (await finance.create(
        FinanceDraft(
          amount: 42,
          type: FinanceTransactionType.expense,
          date: DateTime.utc(2026, 10, 1),
          category: 'кофе',
          note: 'утренний кофе',
        ),
      )).unwrap();

      final byTitle = (await search.search('Flutter')).unwrap();
      expect(byTitle, hasLength(1));
      expect(byTitle.single.type, SearchEntityType.note);
      expect(byTitle.single.entityId, note.id);
      expect(byTitle.single.title, 'Flutter архитектура');

      final byTag = (await search.search('мобильная')).unwrap();
      expect(byTag.single.entityId, note.id);

      final taskHit = (await search.search('сниппет')).unwrap();
      expect(taskHit.single.type, SearchEntityType.task);
      expect(taskHit.single.entityId, task.id);

      final ideaHit = (await search.search('research')).unwrap();
      expect(ideaHit.single.type, SearchEntityType.idea);
      expect(ideaHit.single.entityId, idea.id);

      final financeHit = (await search.search('кофе')).unwrap();
      expect(financeHit.single.type, SearchEntityType.finance);
      expect(financeHit.single.entityId, money.id);

      final prefix = (await search.search('Flut')).unwrap();
      expect(prefix, hasLength(1));
    });

    test('приватные записи исключаются только для LLM-контекста', () async {
      await notes.create(
        const NoteDraft(
          title: 'Секретная заметка',
          body: 'пароль от хранилища',
          isPrivateForLlm: true,
        ),
      );
      await notes.create(
        const NoteDraft(title: 'Публичная заметка', body: 'общий текст'),
      );

      final local = (await search.search('заметка')).unwrap();
      expect(local, hasLength(2));
      expect(local.where((hit) => hit.isPrivateForLlm), hasLength(1));

      final forLlm = (await search.search('заметка', forLlm: true)).unwrap();
      expect(forLlm, hasLength(1));
      expect(forLlm.single.isPrivateForLlm, isFalse);

      expect(
        (await search.search('секретная', forLlm: true)).unwrap(),
        isEmpty,
      );
    });

    test('soft-delete и restore обновляют индекс', () async {
      final note = (await notes.create(
        const NoteDraft(title: 'Удаляемая запись', body: 'уникальное слово'),
      )).unwrap();
      expect((await search.search('уникальное')).unwrap(), hasLength(1));

      await notes.softDelete(note.id).then((r) => r.unwrap());
      expect((await search.search('уникальное')).unwrap(), isEmpty);

      await notes.restore(note.id).then((r) => r.unwrap());
      expect((await search.search('уникальное')).unwrap(), hasLength(1));
    });

    test(
      'rebuild индексирует записи, добавленные в обход репозитория',
      () async {
        await db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                title: 'Прямая вставка',
                body: const Value('индекс пересобран'),
                createdAt: DateTime.now().toUtc(),
                updatedAt: DateTime.now().toUtc(),
              ),
            );
        expect((await search.search('пересобран')).unwrap(), isEmpty);

        await search.rebuild().then((r) => r.unwrap());
        expect((await search.search('пересобран')).unwrap(), hasLength(1));
      },
    );

    test('пустой запрос и спецсимволы не падают', () async {
      expect((await search.search('   ')).unwrap(), isEmpty);
      expect((await search.search('"*()')).unwrap(), isEmpty);
      await notes.create(const NoteDraft(title: 'Обычная заметка'));
      expect((await search.search('"')).unwrap(), isEmpty);
    });

    test('backfill переиндексирует существующую БД', () async {
      final learning = DriftLearningRepository(db);
      await learning.createTrack(
        const LearningTrackDraft(title: 'Old track', goal: 'Legacy content'),
      );
      await db.customStatement('DELETE FROM search_index');

      await ensureSearchIndexVersion(db);

      final hits = (await search.search('Legacy')).unwrap();
      expect(hits.single.type, SearchEntityType.learning);
    });

    test('фильтр типа не теряется после SQL LIMIT', () async {
      for (var i = 0; i < 60; i++) {
        await notes.create(NoteDraft(title: 'filter noise $i'));
      }
      final mail = DriftMailRepository(db, InMemorySecretStore());
      final account = (await mail.createAccount(
        const MailAccountDraft(
          provider: MailProviderType.gmail,
          email: 'filter@example.com',
          clientId: 'client',
        ),
      )).unwrap();
      await mail.upsertMessages(account.id, [
        MailMessageDraft(
          remoteId: 'm1',
          fromAddress: 'sender@example.com',
          subject: 'filter target',
          snippet: 'target',
          body: 'target',
          receivedAt: DateTime.utc(2026, 11, 1),
        ),
      ]);

      final result = (await search.search(
        'filter',
        types: {SearchEntityType.mail},
      )).unwrap();

      expect(result, hasLength(1));
      expect(result.single.type, SearchEntityType.mail);
    });

    test('глобальный индекс: обучение, чат и почта', () async {
      final learning = DriftLearningRepository(db);
      await learning.createTrack(
        const LearningTrackDraft(
          title: 'Kubernetes',
          goal: 'Изучить оркестрацию',
        ),
      );

      final chat = DriftChatRepository(db);
      final thread = (await chat.createThread(
        const ChatThreadDraft(
          title: 'План релиза',
          providerConfigId: null,
          model: 'test',
        ),
      )).unwrap();
      await chat.appendMessage(
        ChatMessageDraft(
          threadId: thread.id,
          role: LlmRole.user,
          content: 'Обсудить глобальный поиск',
        ),
      );

      final mail = DriftMailRepository(db, InMemorySecretStore());
      final account = (await mail.createAccount(
        const MailAccountDraft(
          provider: MailProviderType.gmail,
          email: 'search@example.com',
          clientId: 'client',
        ),
      )).unwrap();
      await mail.upsertMessages(account.id, [
        MailMessageDraft(
          remoteId: 'm1',
          fromAddress: 'sender@example.com',
          subject: 'Аналитика почты',
          snippet: 'Сводка',
          body: 'Тело письма',
          receivedAt: DateTime.utc(2026, 11, 1),
        ),
      ]);

      expect(
        (await search.search('Kubernetes')).unwrap().single.type,
        SearchEntityType.learning,
      );
      expect(
        (await search.search('глобальный')).unwrap().single.type,
        SearchEntityType.chat,
      );
      expect(
        (await search.search('Аналитика')).unwrap().single.type,
        SearchEntityType.mail,
      );
    });
  });
}
