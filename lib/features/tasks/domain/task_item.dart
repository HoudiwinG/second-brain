import '../../../core/result/result.dart';

enum TaskPriority {
  low,
  normal,
  high,
  urgent;

  static TaskPriority fromDb(String value) => values.firstWhere(
    (p) => p.name == value,
    orElse: () => TaskPriority.normal,
  );
}

enum TaskStatus {
  todo,
  inProgress,
  done,
  cancelled;

  String get dbValue => this == TaskStatus.inProgress ? 'in_progress' : name;

  static TaskStatus fromDb(String value) => switch (value) {
    'in_progress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    'cancelled' => TaskStatus.cancelled,
    _ => TaskStatus.todo,
  };
}

/// Задача или напоминание.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueAt,
    required this.remindAt,
    required this.status,
    required this.tags,
    required this.linkedNoteId,
    required this.isPrivateForLlm,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime? dueAt;
  final DateTime? remindAt;
  final TaskStatus status;
  final List<String> tags;
  final int? linkedNoteId;
  final bool isPrivateForLlm;
  final String? recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// Данные для создания/полного обновления задачи.
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description = '',
    this.priority = TaskPriority.normal,
    this.dueAt,
    this.remindAt,
    this.status = TaskStatus.todo,
    this.tags = const [],
    this.linkedNoteId,
    this.isPrivateForLlm = false,
    this.recurrence,
  });

  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime? dueAt;
  final DateTime? remindAt;
  final TaskStatus status;
  final List<String> tags;
  final int? linkedNoteId;
  final bool isPrivateForLlm;
  final String? recurrence;
}

abstract interface class TasksRepository {
  Future<Result<List<TaskItem>>> list({
    TaskStatus? status,
    bool includeDeleted = false,
    bool forLlm = false,
  });

  Future<Result<TaskItem?>> getById(int id, {bool includeDeleted = false});

  Future<Result<TaskItem>> create(TaskDraft draft);

  Future<Result<TaskItem>> update(int id, TaskDraft draft);

  Future<Result<TaskItem>> setStatus(int id, TaskStatus status);

  Future<Result<void>> softDelete(int id);

  Future<Result<void>> restore(int id);
}
