import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/tasks/domain/task_item.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';
import 'tag_utils.dart';

/// Drift-реализация [TasksRepository].
class DriftTasksRepository implements TasksRepository {
  DriftTasksRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<TaskItem>>> list({
    TaskStatus? status,
    bool includeDeleted = false,
    bool forLlm = false,
  }) {
    return RepositoryGuard.guard('TasksRepository.list', () async {
      final query = _db.select(_db.tasks);
      if (!includeDeleted) {
        query.where((t) => t.deletedAt.isNull());
      }
      if (status != null) {
        query.where((t) => t.status.equals(status.dbValue));
      }
      if (forLlm) {
        query.where((t) => t.isPrivateForLlm.equals(false));
      }
      query.orderBy([
        (t) => OrderingTerm.asc(t.status),
        (t) => OrderingTerm.asc(t.dueAt),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
      final rows = await query.get();
      return [
        for (final row in rows) _toDomain(row, await tagsForTask(_db, row.id)),
      ];
    });
  }

  @override
  Future<Result<TaskItem?>> getById(int id, {bool includeDeleted = false}) {
    return RepositoryGuard.guard('TasksRepository.getById', () async {
      final row = await _find(id, includeDeleted: includeDeleted);
      if (row == null) return null;
      return _toDomain(row, await tagsForTask(_db, id));
    });
  }

  @override
  Future<Result<TaskItem>> create(TaskDraft draft) {
    return RepositoryGuard.guard('TasksRepository.create', () async {
      final title = draft.title.trim();
      if (title.isEmpty) {
        throw const ValidationException(
          'TasksRepository: заголовок задачи не может быть пустым',
        );
      }
      final now = DateTime.now().toUtc();
      late TaskItem created;
      await _db.transaction(() async {
        final id = await _db
            .into(_db.tasks)
            .insert(
              db.TasksCompanion.insert(
                title: title,
                description: Value(draft.description),
                priority: Value(draft.priority.name),
                dueAt: Value(draft.dueAt),
                remindAt: Value(draft.remindAt),
                status: Value(draft.status.dbValue),
                linkedNoteId: Value(draft.linkedNoteId),
                isPrivateForLlm: Value(draft.isPrivateForLlm),
                recurrence: Value(draft.recurrence),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await replaceTaskTags(_db, id, draft.tags);
        await indexTask(_db, id);
        final row = await _find(id);
        created = _toDomain(row!, await tagsForTask(_db, id));
      });
      return created;
    });
  }

  @override
  Future<Result<TaskItem>> update(int id, TaskDraft draft) {
    return RepositoryGuard.guard('TasksRepository.update', () async {
      final title = draft.title.trim();
      if (title.isEmpty) {
        throw const ValidationException(
          'TasksRepository: заголовок задачи не может быть пустым',
        );
      }
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('TasksRepository: задача $id не найдена');
      }
      final now = DateTime.now().toUtc();
      final reminderChanged = !_sameInstant(current.remindAt, draft.remindAt);
      late TaskItem updated;
      await _db.transaction(() async {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          db.TasksCompanion(
            title: Value(title),
            description: Value(draft.description),
            priority: Value(draft.priority.name),
            dueAt: Value(draft.dueAt),
            remindAt: Value(draft.remindAt),
            // Изменение времени напоминания снова разрешает показ.
            reminderSentAt: reminderChanged
                ? const Value(null)
                : const Value.absent(),
            status: Value(draft.status.dbValue),
            linkedNoteId: Value(draft.linkedNoteId),
            isPrivateForLlm: Value(draft.isPrivateForLlm),
            recurrence: Value(draft.recurrence),
            updatedAt: Value(now),
          ),
        );
        await replaceTaskTags(_db, id, draft.tags);
        await indexTask(_db, id);
        final row = await _find(id);
        updated = _toDomain(row!, await tagsForTask(_db, id));
      });
      return updated;
    });
  }

  @override
  Future<Result<TaskItem>> setStatus(int id, TaskStatus status) {
    return RepositoryGuard.guard('TasksRepository.setStatus', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('TasksRepository: задача $id не найдена');
      }
      await _db.transaction(() async {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          db.TasksCompanion(
            status: Value(status.dbValue),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexTask(_db, id);
      });
      final row = await _find(id);
      return _toDomain(row!, await tagsForTask(_db, id));
    });
  }

  @override
  Future<Result<List<TaskItem>>> dueReminders(DateTime now) {
    return RepositoryGuard.guard('TasksRepository.dueReminders', () async {
      final query = _db.select(_db.tasks)
        ..where((t) => t.deletedAt.isNull())
        ..where((t) => t.remindAt.isNotNull())
        ..where((t) => t.remindAt.isSmallerOrEqualValue(now.toUtc()))
        ..where((t) => t.reminderSentAt.isNull())
        ..where(
          (t) => t.status.isIn([
            TaskStatus.todo.dbValue,
            TaskStatus.inProgress.dbValue,
          ]),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.remindAt)]);
      final rows = await query.get();
      return [
        for (final row in rows) _toDomain(row, await tagsForTask(_db, row.id)),
      ];
    });
  }

  @override
  Future<Result<void>> markReminderSent(
    int id, {
    required DateTime remindAt,
  }) {
    return RepositoryGuard.guard('TasksRepository.markReminderSent', () async {
      final now = DateTime.now().toUtc();
      await (_db.update(_db.tasks)..where(
            (t) =>
                t.id.equals(id) &
                t.remindAt.equals(remindAt.toUtc()) &
                t.reminderSentAt.isNull(),
          ))
          .write(
            db.TasksCompanion(
              reminderSentAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
  }

  @override
  Future<Result<void>> softDelete(int id) {
    return RepositoryGuard.guard('TasksRepository.softDelete', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('TasksRepository: задача $id не найдена');
      }
      final now = DateTime.now().toUtc();
      await _db.transaction(() async {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          db.TasksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        await indexTask(_db, id);
      });
    });
  }

  @override
  Future<Result<void>> restore(int id) {
    return RepositoryGuard.guard('TasksRepository.restore', () async {
      final current = await _find(id, includeDeleted: true);
      if (current == null) {
        throw ValidationException('TasksRepository: задача $id не найдена');
      }
      await _db.transaction(() async {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          db.TasksCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexTask(_db, id);
      });
    });
  }

  Future<db.Task?> _find(int id, {bool includeDeleted = false}) {
    final query = _db.select(_db.tasks)..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  static bool _sameInstant(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.toUtc() == b.toUtc();
  }

  TaskItem _toDomain(db.Task row, List<String> tags) => TaskItem(
    id: row.id,
    title: row.title,
    description: row.description,
    priority: TaskPriority.fromDb(row.priority),
    dueAt: row.dueAt,
    remindAt: row.remindAt,
    reminderSentAt: row.reminderSentAt,
    status: TaskStatus.fromDb(row.status),
    tags: List.unmodifiable(tags),
    linkedNoteId: row.linkedNoteId,
    isPrivateForLlm: row.isPrivateForLlm,
    recurrence: row.recurrence,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
