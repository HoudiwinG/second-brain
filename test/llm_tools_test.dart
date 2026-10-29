import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/search_repository.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/data/repositories/tool_audit_repository.dart';
import 'package:second_brain/features/llm/tools/built_in/create_note_tool.dart';
import 'package:second_brain/features/llm/tools/built_in/create_task_tool.dart';
import 'package:second_brain/features/llm/tools/built_in/search_data_tool.dart';
import 'package:second_brain/features/llm/tools/built_in/summarize_mail_mock_tool.dart';
import 'package:second_brain/features/llm/tools/built_in/update_task_status_tool.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/search/domain/search_hit.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

void main() {
  late TasksRepository tasks;
  late NotesRepository notes;
  late SearchRepository search;

  setUp(() {
    final db = InMemoryDbFactory.open();
    tasks = DriftTasksRepository(db);
    notes = DriftNotesRepository(db);
    search = DriftSearchRepository(db);
  });

  group('create_task', () {
    test('создаёт задачу с напоминанием и приоритетом', () async {
      final tool = CreateTaskTool(tasks);

      final result = await tool.execute({
        'title': '  Купить молоко  ',
        'priority': 'high',
        'remind_at': '2026-11-01T09:00:00',
        'tags': ['дом'],
      });

      final data = result.unwrap();
      expect(data['title'], 'Купить молоко');
      expect(data['remind_at'], isNotNull);
      final saved = (await tasks.getById(data['id'] as int)).unwrap()!;
      expect(saved.priority, TaskPriority.high);
      expect(saved.tags, ['дом']);
      expect(saved.isPrivateForLlm, isFalse);
    });

    test('без title и с неверным приоритетом возвращает ошибку', () async {
      final tool = CreateTaskTool(tasks);

      expect(await tool.execute({}), isA<Failure<Map<String, Object?>>>());
      final bad = await tool.execute({'title': 'x', 'priority': 'ничего'});
      expect(bad, isA<Failure<Map<String, Object?>>>());
      expect(
        (await tasks.list()).unwrap(),
        isEmpty,
        reason: 'ошибка не должна создавать задачу',
      );
    });

    test('ошибка не содержит значения аргумента', () async {
      final tool = CreateTaskTool(tasks);

      final result = await tool.execute({
        'title': 'Секретный заголовок',
        'remind_at': 'не дата',
      });

      expect(result, isA<Failure<Map<String, Object?>>>());
      expect(result.toString(), isNot(contains('Секретный')));
    });
  });

  group('create_note', () {
    test('создаёт заметку и сохраняет флаг приватности', () async {
      final tool = CreateNoteTool(notes);

      final data = (await tool.execute({
        'title': 'Идея',
        'body': 'Текст',
        'is_private': true,
      })).unwrap();

      final saved = (await notes.getById(data['id'] as int)).unwrap()!;
      expect(saved.body, 'Текст');
      expect(saved.isPrivateForLlm, isTrue);
    });
  });

  group('update_task_status', () {
    test('меняет статус по dbValue', () async {
      final task = (await tasks.create(const TaskDraft(title: 'Отчёт')))
          .unwrap();
      final tool = UpdateTaskStatusTool(tasks);

      final data = (await tool.execute({
        'task_id': task.id,
        'status': 'in_progress',
      })).unwrap();

      expect(data['status'], 'in_progress');
      expect(
        (await tasks.getById(task.id)).unwrap()!.status,
        TaskStatus.inProgress,
      );
    });

    test('не трогает приватную задачу и несуществующий id', () async {
      final secret = (await tasks.create(
        const TaskDraft(title: 'Секрет', isPrivateForLlm: true),
      )).unwrap();
      final tool = UpdateTaskStatusTool(tasks);

      expect(
        await tool.execute({'task_id': secret.id, 'status': 'done'}),
        isA<Failure<Map<String, Object?>>>(),
      );
      expect(
        await tool.execute({'task_id': 9999, 'status': 'done'}),
        isA<Failure<Map<String, Object?>>>(),
      );
      expect(
        (await tasks.getById(secret.id)).unwrap()!.status,
        TaskStatus.todo,
      );
    });

    test('неизвестный статус отклоняется', () async {
      final task = (await tasks.create(const TaskDraft(title: 'Отчёт')))
          .unwrap();

      final result = await UpdateTaskStatusTool(tasks)
          .execute({'task_id': task.id, 'status': 'inProgress'});

      expect(result, isA<Failure<Map<String, Object?>>>());
    });
  });

  group('search_data', () {
    test('не возвращает приватные записи', () async {
      await notes.create(
        const NoteDraft(title: 'Открытая', body: 'слово альфа'),
      );
      await notes.create(
        const NoteDraft(
          title: 'Скрытая',
          body: 'слово альфа',
          isPrivateForLlm: true,
        ),
      );
      final tool = SearchDataTool(search);

      final data = (await tool.execute({'query': 'альфа'})).unwrap();

      final results = data['results']! as List<Map<String, Object?>>;
      expect(results.map((hit) => hit['title']), ['Открытая']);
    });

    test('пустой запрос возвращает ошибку', () async {
      final result = await SearchDataTool(search).execute({'query': '  '});

      expect(result, isA<Failure<Map<String, Object?>>>());
    });
  });

  group('tool_audit_log', () {
    test('хранит имена аргументов и не хранит их значения', () async {
      final audit = DriftToolAuditRepository(InMemoryDbFactory.open());
      final createdAt = DateTime.utc(2026, 10, 29, 10);

      await audit.record(
        ToolAuditDraft(
          toolName: 'create_note',
          status: ToolAuditStatus.ok,
          argumentNames: const ['title', 'body'],
          entityId: 7,
          createdAt: createdAt,
        ),
      );

      final recent = (await audit.listRecent()).unwrap();
      expect(recent, hasLength(1));
      expect(recent.single.argumentNames, ['title', 'body']);
      expect(recent.single.entityId, 7);
      expect(recent.single.status, ToolAuditStatus.ok);
    });

    test('сортирует от новых к старым', () async {
      final audit = DriftToolAuditRepository(InMemoryDbFactory.open());
      for (var i = 0; i < 3; i++) {
        await audit.record(
          ToolAuditDraft(
            toolName: 'tool_$i',
            status: ToolAuditStatus.unknownTool,
            createdAt: DateTime.utc(2026, 10, 29, i),
          ),
        );
      }

      final recent = (await audit.listRecent(limit: 2)).unwrap();
      expect(recent.map((draft) => draft.toolName), ['tool_2', 'tool_1']);
    });
  });

  group('summarize_mail_mock', () {
    test('возвращает мок-письма с пометкой source и лимитом', () async {
      final data = (await SummarizeMailMockTool().execute({'limit': 2}))
          .unwrap();

      expect(data['source'], 'mock');
      expect(data['messages'], hasLength(2));
    });
  });
}
