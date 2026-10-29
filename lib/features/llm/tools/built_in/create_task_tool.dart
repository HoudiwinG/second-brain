import '../../../../core/result/result.dart';
import '../../../tasks/domain/task_item.dart';
import '../llm_tool_registry.dart';
import 'tool_args.dart';

/// Создание задачи. Напоминание — это задача с `remind_at`.
final class CreateTaskTool extends LlmToolBase {
  CreateTaskTool(this._tasks);

  final TasksRepository _tasks;

  @override
  String get name => 'create_task';

  @override
  String get description =>
      'Создать задачу или напоминание. Укажите remind_at, чтобы напомнить в '
      'заданное время.';

  @override
  Map<String, Object?> get parameters => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': 'Название задачи'},
      'description': {'type': 'string'},
      'priority': {
        'type': 'string',
        'enum': ['low', 'normal', 'high', 'urgent'],
      },
      'due_at': {'type': 'string', 'description': 'Срок, ISO 8601'},
      'remind_at': {'type': 'string', 'description': 'Напоминание, ISO 8601'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'is_private': {
        'type': 'boolean',
        'description': 'Скрыть задачу от будущих запросов ассистента',
      },
    },
    'required': ['title'],
  };

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async {
    try {
      final draft = TaskDraft(
        title: ToolArgs.requireString(arguments, 'title'),
        description: ToolArgs.optionalString(arguments, 'description') ?? '',
        priority:
            ToolArgs.optionalEnum(arguments, 'priority', TaskPriority.values) ??
            TaskPriority.normal,
        dueAt: ToolArgs.optionalDateTime(arguments, 'due_at'),
        remindAt: ToolArgs.optionalDateTime(arguments, 'remind_at'),
        tags: ToolArgs.optionalStringList(arguments, 'tags'),
        isPrivateForLlm: ToolArgs.optionalBool(arguments, 'is_private'),
      );
      final created = (await _tasks.create(draft)).unwrap();
      return Result.success({
        'id': created.id,
        'title': created.title,
        'remind_at': created.remindAt?.toIso8601String(),
      });
    } catch (error) {
      return Result.failure(toToolException(error));
    }
  }
}
