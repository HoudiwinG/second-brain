import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/backup/backup_service.dart';
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/data/repositories/categories_repository.dart';
import 'package:second_brain/data/repositories/finance_repository.dart';
import 'package:second_brain/data/repositories/ideas_repository.dart';
import 'package:second_brain/data/repositories/learning_repository.dart';
import 'package:second_brain/data/repositories/mail_repository.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/search_repository.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/features/finance/domain/finance_transaction.dart';
import 'package:second_brain/features/ideas/domain/idea_entry.dart';
import 'package:second_brain/features/learning/domain/learning_session.dart';
import 'package:second_brain/features/learning/domain/learning_track.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late BackupService backup;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('second_brain_backup_');
    db = InMemoryDbFactory.open();
    backup = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test(
    'JSON round-trip сохраняет сущности, связи, теги и приватность',
    () async {
      final categories = DriftCategoriesRepository(db);
      final notes = DriftNotesRepository(db);
      final tasks = DriftTasksRepository(db);
      final ideas = DriftIdeasRepository(db);
      final finance = DriftFinanceRepository(db);

      final root = (await categories.create(name: 'Работа')).unwrap();
      final child = (await categories.create(
        name: 'Проекты',
        parentId: root.id,
      )).unwrap();
      final note = (await notes.create(
        NoteDraft(
          title: 'Приватная заметка',
          body: 'Текст для бэкапа',
          categoryId: child.id,
          tags: const ['секрет', 'план'],
          isPrivateForLlm: true,
        ),
      )).unwrap();
      final task = (await tasks.create(
        TaskDraft(
          title: 'Связанная задача',
          remindAt: DateTime.utc(2026, 10, 4, 9),
          linkedNoteId: note.id,
          tags: const ['план'],
          priority: TaskPriority.high,
        ),
      )).unwrap();
      await tasks
          .markReminderSent(task.id, remindAt: DateTime.utc(2026, 10, 4, 9))
          .then((r) => r.unwrap());
      final sentAt = (await tasks.getById(task.id)).unwrap()!.reminderSentAt!;
      final idea = (await ideas.create(
        const IdeaDraft(text: 'Идея для бэкапа', tags: ['идеи']),
      )).unwrap();
      final transaction = (await finance.create(
        FinanceDraft(
          amount: 99.9,
          type: FinanceTransactionType.expense,
          date: DateTime.utc(2026, 10, 3),
          category: 'тест',
          note: 'проверка',
          isPrivateForLlm: true,
        ),
      )).unwrap();
      final learning = DriftLearningRepository(db);
      final track = (await learning.createTrack(
        const LearningTrackDraft(
          title: 'Dart',
          goal: 'Писать приложения',
          steps: [
            LearningStep(
              id: 's1',
              title: 'Основы',
              status: LearningStepStatus.inProgress,
            ),
          ],
          customFields: {'hours': '10'},
          isPrivateForLlm: true,
        ),
      )).unwrap();
      final session = (await learning.addSession(
        LearningSessionDraft(
          trackId: track.id,
          durationMinutes: 45,
          notes: 'Практика',
          date: DateTime.utc(2026, 10, 5),
        ),
      )).unwrap();
      final mail = DriftMailRepository(db, InMemorySecretStore());
      final mailAccount = (await mail.createAccount(
        const MailAccountDraft(
          provider: MailProviderType.gmail,
          email: 'mail@example.com',
          clientId: 'client',
          isPrivateForLlm: true,
        ),
      )).unwrap();
      final mailMessage = (await mail.upsertMessages(mailAccount.id, [
        MailMessageDraft(
          remoteId: 'remote-1',
          threadId: 'thread-1',
          fromAddress: 'sender@example.com',
          subject: 'Письмо',
          snippet: 'Кратко',
          body: 'Тело',
          receivedAt: DateTime.utc(2026, 10, 6),
        ),
      ])).unwrap();

      final file = File('${temp.path}/backup.json');
      await backup.exportJson(file).then((r) => r.unwrap());
      expect(file.existsSync(), isTrue);
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(decoded['format'], BackupService.format);
      expect(decoded['version'], BackupService.version);
      expect(decoded['notes'], hasLength(1));
      expect(decoded['learning_tracks'], hasLength(1));
      expect(decoded['learning_sessions'], hasLength(1));
      expect(decoded['mail_accounts'], hasLength(1));
      expect(decoded['mail_messages'], hasLength(1));

      // Импорт заменяет содержимое: лишняя запись должна исчезнуть.
      await notes.create(const NoteDraft(title: 'Лишняя'));
      await backup.importJson(file).then((r) => r.unwrap());

      final restoredNotes = (await notes.list()).unwrap();
      expect(restoredNotes, hasLength(1));
      expect(restoredNotes.single.id, note.id);
      expect(restoredNotes.single.title, 'Приватная заметка');
      expect(restoredNotes.single.categoryId, child.id);
      expect(restoredNotes.single.tags, ['план', 'секрет']);
      expect(restoredNotes.single.isPrivateForLlm, isTrue);

      final restoredTasks = (await tasks.list()).unwrap();
      expect(restoredTasks, hasLength(1));
      expect(restoredTasks.single.id, task.id);
      expect(restoredTasks.single.linkedNoteId, note.id);
      expect(restoredTasks.single.tags, ['план']);
      expect(restoredTasks.single.priority, TaskPriority.high);
      expect(
        restoredTasks.single.remindAt?.toUtc(),
        DateTime.utc(2026, 10, 4, 9),
      );
      expect(restoredTasks.single.reminderSentAt?.toUtc(), sentAt.toUtc());

      final restoredIdeas = (await ideas.list()).unwrap();
      expect(restoredIdeas, hasLength(1));
      expect(restoredIdeas.single.id, idea.id);
      expect(restoredIdeas.single.tags, ['идеи']);

      final restoredFinance = (await finance.list()).unwrap();
      expect(restoredFinance, hasLength(1));
      expect(restoredFinance.single.id, transaction.id);
      expect(restoredFinance.single.amount, 99.9);
      expect(restoredFinance.single.isPrivateForLlm, isTrue);

      final restoredCategories = (await categories.list()).unwrap();
      expect(restoredCategories, hasLength(2));
      expect(
        restoredCategories.singleWhere((c) => c.id == child.id).parentId,
        root.id,
      );

      final restoredTracks = (await learning.listTracks()).unwrap();
      expect(restoredTracks, hasLength(1));
      expect(restoredTracks.single.id, track.id);
      expect(restoredTracks.single.title, 'Dart');
      expect(restoredTracks.single.goal, 'Писать приложения');
      expect(restoredTracks.single.steps.single.title, 'Основы');
      expect(restoredTracks.single.customFields['hours'], '10');
      expect(restoredTracks.single.isPrivateForLlm, isTrue);
      final restoredSessions = (await learning.listSessions(track.id)).unwrap();
      expect(restoredSessions, hasLength(1));
      expect(restoredSessions.single.id, session.id);
      expect(restoredSessions.single.durationMinutes, 45);
      expect(restoredSessions.single.notes, 'Практика');

      final restoredAccounts = (await mail.listAccounts()).unwrap();
      expect(restoredAccounts, hasLength(1));
      expect(restoredAccounts.single.email, 'mail@example.com');
      expect(restoredAccounts.single.isPrivateForLlm, isTrue);
      final restoredMail = (await mail.listMessages()).unwrap();
      expect(restoredMail, hasLength(1));
      expect(restoredMail.single.subject, 'Письмо');
      expect(restoredMail.single.isPrivateForLlm, isTrue);
      expect(mailMessage, 1);

      // После импорта FTS-индекс должен работать.
      final search = DriftSearchRepository(db);
      expect((await search.search('бэкап')).unwrap(), isNotEmpty);
    },
  );

  test('JSON v1 без обучения импортируется как совместимый', () async {
    final file = File('${temp.path}/v1.json');
    await file.writeAsString(
      jsonEncode({
        'format': BackupService.format,
        'version': 1,
        'exported_at': DateTime.utc(2026, 11, 1).toIso8601String(),
        'categories': [],
        'tags': [],
        'notes': [],
        'tasks': [],
        'ideas': [],
        'finance': [],
      }),
    );

    final result = await backup.importJson(file);

    expect(result, isA<Success<void>>());
    expect(await db.select(db.learningTracks).get(), isEmpty);
  });

  test('JSON v2 без learning-массивов отклоняется', () async {
    final file = File('${temp.path}/v2-no-learning.json');
    await file.writeAsString(
      jsonEncode({
        'format': BackupService.format,
        'version': 2,
        'exported_at': DateTime.utc(2026, 11, 1).toIso8601String(),
        'categories': [],
        'tags': [],
        'notes': [],
        'tasks': [],
        'ideas': [],
        'finance': [],
      }),
    );

    expect(await backup.importJson(file), isA<Failure<void>>());
  });

  test('JSON: неизвестный формат не очищает данные', () async {
    final notes = DriftNotesRepository(db);
    await notes.create(const NoteDraft(title: 'Остаётся'));
    final file = File('${temp.path}/bad.json');
    await file.writeAsString('{"format":"other","version":1}');

    final result = await backup.importJson(file);
    expect(result, isA<Failure<void>>());
    expect((await notes.list()).unwrap(), hasLength(1));
  });

  test('CSV round-trip финансов с экранированием', () async {
    final finance = DriftFinanceRepository(db);
    await finance.create(
      FinanceDraft(
        amount: 12.5,
        type: FinanceTransactionType.expense,
        date: DateTime.utc(2026, 10, 4),
        category: 'кафе, "утро"',
        account: 'карта',
        note: 'строка 1\nстрока 2',
        isPrivateForLlm: true,
      ),
    );
    await finance.create(
      FinanceDraft(
        amount: 100,
        type: FinanceTransactionType.income,
        date: DateTime.utc(2026, 10, 5),
        category: 'зарплата',
      ),
    );

    final file = File('${temp.path}/finance.csv');
    await backup.exportFinanceCsv(file).then((r) => r.unwrap());
    final raw = await file.readAsString();
    expect(raw, contains('"кафе, ""утро"""'));
    expect(raw, contains('"строка 1'));

    final target = InMemoryDbFactory.open();
    addTearDown(target.close);
    final targetBackup = BackupService(target);
    await targetBackup.importFinanceCsv(file).then((r) => r.unwrap());

    final restored = (await DriftFinanceRepository(target).list()).unwrap();
    expect(restored, hasLength(2));
    final expense = restored.singleWhere(
      (t) => t.type == FinanceTransactionType.expense,
    );
    expect(expense.amount, 12.5);
    expect(expense.category, 'кафе, "утро"');
    expect(expense.note, 'строка 1\nстрока 2');
    expect(expense.isPrivateForLlm, isTrue);
  });

  test('JSON: includeDeleted управляет экспортом', () async {
    final notes = DriftNotesRepository(db);
    final note = (await notes.create(const NoteDraft(title: 'Удалённая')))
        .unwrap();
    await notes.softDelete(note.id).then((r) => r.unwrap());

    final visible = File('${temp.path}/visible.json');
    await backup.exportJson(visible).then((r) => r.unwrap());
    final visibleJson =
        jsonDecode(await visible.readAsString()) as Map<String, dynamic>;
    expect(visibleJson['notes'], isEmpty);

    final all = File('${temp.path}/all.json');
    await backup.exportJson(all, includeDeleted: true).then((r) => r.unwrap());
    final allJson =
        jsonDecode(await all.readAsString()) as Map<String, dynamic>;
    expect(allJson['notes'], hasLength(1));
  });
}
