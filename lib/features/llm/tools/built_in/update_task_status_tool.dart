import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../../tasks/domain/task_item.dart';
import '../llm_tool_registry.dart';
import 'tool_args.dart';

/// Обновление статуса задачи в трекере. Приватные задачи недоступны.
final class UpdateTaskStatusTool extends LlmToolBase {
  UpdateTaskStatusTool(this._tasks);

  final TasksRepository _tasks;

  @override
  String get name => 'update_task_status';

  @override
  String get description =>
      'Изменить статус задачи по id (todo, in_progress, done, cancelled).';

  @override
  Map<String, Object?> get parameters => {
    'type': 'object',
    'properties': {
      'task_id': {'type': 'integer', 'description': 'Id задачи'},
      'status': {
        'type': 'string',
        'enum': TaskStatus.values.map((status) => status.dbValue).toList(),
      },
    },
    'required': ['task_id', 'status'],
  };

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async {
    try {
      final id = ToolArgs.requireInt(arguments, 'task_id');
      final statusRaw = ToolArgs.requireString(arguments, 'status');
      final status = TaskStatus.values.where(
        (value) => value.dbValue == statusRaw,
      );
      if (status.isEmpty) {
        throw const ValidationException('Аргумент "status" недопустим');
      }

      // Проверка приватности и запись выполняются одним UPDATE: отдельное
      // чтение дало бы гонку и позволило бы отличить приватную задачу от
      // несуществующей.
      final updated = (await _tasks.setStatusForLlm(
        id,
        status.single,
      )).unwrap();
      return Result.success({
        'id': updated.id,
        'status': updated.status.dbValue,
      });
    } catch (error) {
      return Result.failure(toToolException(error));
    }
  }
}
