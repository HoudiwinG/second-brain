import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/db/app_database.dart'
    hide FinanceTransaction, IdeaEntry, Note;
import 'package:second_brain/data/repositories/categories_repository.dart';
import 'package:second_brain/data/repositories/finance_repository.dart';
import 'package:second_brain/data/repositories/ideas_repository.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/features/finance/domain/finance_transaction.dart';
import 'package:second_brain/features/ideas/domain/idea_entry.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

void main() {
  group('NotesRepository', () {
    late AppDatabase db;
    late DriftNotesRepository repo;
    late DriftCategoriesRepository categories;

    setUp(() {
      db = InMemoryDbFactory.open();
      repo = DriftNotesRepository(db);
      categories = DriftCategoriesRepository(db);
    });
    tearDown(() => db.close());

    test('CRUD, категории, теги и приватность', () async {
      final category = (await categories.create(name: 'Работа')).unwrap();
      final created = (await repo.create(
        NoteDraft(
          title: '  План недели ',
          body: 'Сделать обзор',
          categoryId: category.id,
          tags: const ['Работа', 'планы'],
        ),
      )).unwrap();

      expect(created.id, greaterThan(0));
      expect(created.title, 'План недели');
      expect(created.categoryId, category.id);
      expect(created.tags, unorderedEquals(['Работа', 'планы']));
      expect(created.isPrivateForLlm, isFalse);

      final updated = (await repo.update(
        created.id,
        const NoteDraft(
          title: 'План на неделю',
          body: 'Обновлено',
          tags: ['Работа'],
          isPrivateForLlm: true,
        ),
      )).unwrap();
      expect(updated.title, 'План на неделю');
      expect(updated.body, 'Обновлено');
      expect(updated.categoryId, isNull);
      expect(updated.tags, ['Работа']);
      expect(updated.isPrivateForLlm, isTrue);

      final list = (await repo.list()).unwrap();
      expect(list, hasLength(1));
      expect((await repo.list(forLlm: true)).unwrap(), isEmpty);

      await repo.softDelete(created.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), isEmpty);
      expect((await repo.getById(created.id)).unwrap(), isNull);
      expect(
        (await repo.list(includeDeleted: true)).unwrap().single.isDeleted,
        isTrue,
      );

      await repo.restore(created.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap().single.title, 'План на неделю');
      expect((await repo.list(forLlm: true)).unwrap(), isEmpty);
    });

    test('валидация пустого заголовка', () async {
      final result = await repo.create(const NoteDraft(title: '   '));
      expect(result, isA<Failure<Note>>());
    });

    test('getById возвращает null для отсутствующей записи', () async {
      expect((await repo.getById(999)).unwrap(), isNull);
    });
  });

  group('TasksRepository', () {
    late AppDatabase db;
    late DriftTasksRepository repo;
    late DriftNotesRepository notes;

    setUp(() {
      db = InMemoryDbFactory.open();
      repo = DriftTasksRepository(db);
      notes = DriftNotesRepository(db);
    });
    tearDown(() => db.close());

    test('CRUD, фильтры, смена статуса и soft-delete', () async {
      final note = (await notes.create(
        const NoteDraft(title: 'Связанная заметка'),
      )).unwrap();
      final created = (await repo.create(
        TaskDraft(
          title: '  Проверить макет ',
          description: 'До встречи',
          priority: TaskPriority.high,
          dueAt: DateTime.utc(2026, 11, 1),
          remindAt: DateTime.utc(2026, 10, 31),
          tags: const ['дизайн'],
          linkedNoteId: note.id,
          recurrence: 'weekly',
        ),
      )).unwrap();

      expect(created.title, 'Проверить макет');
      expect(created.priority, TaskPriority.high);
      expect(created.status, TaskStatus.todo);
      expect(created.tags, ['дизайн']);
      expect(created.linkedNoteId, note.id);
      expect(created.recurrence, 'weekly');

      final updated = (await repo.update(
        created.id,
        TaskDraft(
          title: 'Проверить макет v2',
          priority: TaskPriority.urgent,
          status: TaskStatus.inProgress,
          tags: const ['дизайн', 'срочно'],
          linkedNoteId: note.id,
          isPrivateForLlm: true,
        ),
      )).unwrap();
      expect(updated.priority, TaskPriority.urgent);
      expect(updated.status, TaskStatus.inProgress);
      expect(updated.tags, ['дизайн', 'срочно']);
      expect((await repo.list(forLlm: true)).unwrap(), isEmpty);

      final done = (await repo.setStatus(created.id, TaskStatus.done)).unwrap();
      expect(done.status, TaskStatus.done);
      expect((await repo.list(status: TaskStatus.done)).unwrap(), hasLength(1));
      expect((await repo.list(status: TaskStatus.todo)).unwrap(), isEmpty);

      final second = (await repo.create(const TaskDraft(title: 'Вторая')))
          .unwrap();
      await repo.softDelete(second.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), hasLength(1));
      expect((await repo.list(includeDeleted: true)).unwrap(), hasLength(2));
      await repo.restore(second.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), hasLength(2));
    });
  });

  group('IdeasRepository', () {
    late AppDatabase db;
    late DriftIdeasRepository repo;

    setUp(() {
      db = InMemoryDbFactory.open();
      repo = DriftIdeasRepository(db);
    });
    tearDown(() => db.close());

    test('CRUD, теги и приватность', () async {
      final created = (await repo.create(
        const IdeaDraft(
          text: '  Идея приложения ',
          source: 'прогулка',
          mood: 'вдохновение',
          tags: ['продукт'],
        ),
      )).unwrap();
      expect(created.text, 'Идея приложения');
      expect(created.mood, 'вдохновение');
      expect(created.tags, ['продукт']);

      final updated = (await repo.update(
        created.id,
        const IdeaDraft(text: 'Идея v2', isPrivateForLlm: true),
      )).unwrap();
      expect(updated.text, 'Идея v2');
      expect(updated.source, isNull);
      expect((await repo.list(forLlm: true)).unwrap(), isEmpty);

      await repo.softDelete(created.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), isEmpty);
      await repo.restore(created.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), hasLength(1));
    });

    test('валидация пустого текста', () async {
      expect(
        await repo.create(const IdeaDraft(text: '  ')),
        isA<Failure<IdeaEntry>>(),
      );
    });
  });

  group('FinanceRepository', () {
    late AppDatabase db;
    late DriftFinanceRepository repo;

    setUp(() {
      db = InMemoryDbFactory.open();
      repo = DriftFinanceRepository(db);
    });
    tearDown(() => db.close());

    test('CRUD, фильтры и сводка', () async {
      final income = (await repo.create(
        FinanceDraft(
          amount: 1000,
          type: FinanceTransactionType.income,
          date: DateTime.utc(2026, 10, 1),
          category: 'зарплата',
          account: 'карта',
        ),
      )).unwrap();
      final expense = (await repo.create(
        FinanceDraft(
          amount: 250.5,
          type: FinanceTransactionType.expense,
          date: DateTime.utc(2026, 10, 2),
          category: 'продукты',
          currency: 'rub',
          isPrivateForLlm: true,
        ),
      )).unwrap();
      expect(income.signedAmount, 1000);
      expect(expense.signedAmount, -250.5);
      expect(expense.currency, 'RUB');

      final summary = (await repo.summary()).unwrap();
      expect(summary.income, 1000);
      expect(summary.expense, 250.5);
      expect(summary.balance, 749.5);
      expect(summary.transactions, 2);

      expect(
        (await repo.list(type: FinanceTransactionType.expense)).unwrap(),
        hasLength(1),
      );
      expect((await repo.list(forLlm: true)).unwrap(), hasLength(1));
      expect(
        (await repo.list(
          from: DateTime.utc(2026, 10, 2),
          to: DateTime.utc(2026, 10, 2, 23, 59),
        )).unwrap(),
        hasLength(1),
      );

      final updated = (await repo.update(
        expense.id,
        FinanceDraft(
          amount: 300,
          type: FinanceTransactionType.expense,
          date: expense.date,
          category: 'кафе',
        ),
      )).unwrap();
      expect(updated.amount, 300);
      expect(updated.category, 'кафе');
      expect(updated.isPrivateForLlm, isFalse);

      await repo.softDelete(income.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), hasLength(1));
      expect((await repo.summary()).unwrap().income, 0);
      await repo.restore(income.id).then((r) => r.unwrap());
      expect((await repo.list()).unwrap(), hasLength(2));
    });

    test('валидация суммы и валюты', () async {
      final zero = await repo.create(
        FinanceDraft(
          amount: 0,
          type: FinanceTransactionType.expense,
          date: DateTime.utc(2026, 1, 1),
        ),
      );
      expect(zero, isA<Failure<FinanceTransaction>>());

      final noCurrency = await repo.create(
        FinanceDraft(
          amount: 10,
          type: FinanceTransactionType.expense,
          date: DateTime.utc(2026, 1, 1),
          currency: ' ',
        ),
      );
      expect(noCurrency, isA<Failure<FinanceTransaction>>());
    });
  });

  group('CategoriesRepository', () {
    late AppDatabase db;
    late DriftCategoriesRepository repo;

    setUp(() {
      db = InMemoryDbFactory.open();
      repo = DriftCategoriesRepository(db);
    });
    tearDown(() => db.close());

    test('иерархия, обновление и запрет цикла', () async {
      final root = (await repo.create(name: 'Корень')).unwrap();
      final child = (await repo.create(
        name: 'Ребёнок',
        parentId: root.id,
      )).unwrap();
      expect((await repo.list()).unwrap(), hasLength(2));
      expect(child.parentId, root.id);

      final renamed = (await repo.update(
        child.id,
        name: 'Ребёнок 2',
        parentId: root.id,
      )).unwrap();
      expect(renamed.name, 'Ребёнок 2');

      final cycle = await repo.update(
        root.id,
        name: 'Корень',
        parentId: child.id,
      );
      expect(cycle, isA<Failure<void>>());

      await repo.delete(root.id).then((r) => r.unwrap());
      expect((await repo.getById(root.id)).unwrap(), isNull);
    });
  });
}
