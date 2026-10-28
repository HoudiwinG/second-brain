import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import 'privacy_guard.dart';

/// Тип сущности, которую можно приложить к LLM-запросу.
enum LlmContextEntityType { note, task, idea }

/// Ссылка на сущность. Содержимое и флаг приватности читаются из БД.
///
/// Вызывающий код не может передать собственный `isPrivateForLlm`: это
/// исключает случайную отправку приватной сущности во внешнюю LLM.
final class LlmContextRef {
  const LlmContextRef(this.type, this.id);

  final LlmContextEntityType type;
  final int id;

  @override
  bool operator ==(Object other) =>
      other is LlmContextRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Загружает контекст и флаги приватности из БД.
abstract interface class LlmContextLoader {
  Future<List<LlmContextItem>> load(Iterable<LlmContextRef> refs);
}

/// Production-реализация: единственный источник [LlmContextItem].
final class DriftLlmContextLoader implements LlmContextLoader {
  DriftLlmContextLoader(this._db);

  final AppDatabase _db;

  @override
  Future<List<LlmContextItem>> load(Iterable<LlmContextRef> refs) async {
    final unique = <LlmContextRef>{...refs};
    if (unique.isEmpty) return const [];

    final noteIds = {
      for (final ref in unique)
        if (ref.type == LlmContextEntityType.note) ref.id,
    };
    final taskIds = {
      for (final ref in unique)
        if (ref.type == LlmContextEntityType.task) ref.id,
    };
    final ideaIds = {
      for (final ref in unique)
        if (ref.type == LlmContextEntityType.idea) ref.id,
    };

    final notes = noteIds.isEmpty
        ? const <Note>[]
        : await (_db.select(
            _db.notes,
          )..where((t) => t.id.isIn(noteIds) & t.deletedAt.isNull())).get();
    final tasks = taskIds.isEmpty
        ? const <Task>[]
        : await (_db.select(
            _db.tasks,
          )..where((t) => t.id.isIn(taskIds) & t.deletedAt.isNull())).get();
    final ideas = ideaIds.isEmpty
        ? const <IdeaEntry>[]
        : await (_db.select(
            _db.ideaEntries,
          )..where((t) => t.id.isIn(ideaIds) & t.deletedAt.isNull())).get();

    final notesById = {for (final row in notes) row.id: row};
    final tasksById = {for (final row in tasks) row.id: row};
    final ideasById = {for (final row in ideas) row.id: row};

    final items = <LlmContextItem>[];
    for (final ref in unique) {
      switch (ref.type) {
        case LlmContextEntityType.note:
          final row = notesById[ref.id];
          if (row == null) continue;
          items.add(
            LlmContextItem(
              entityType: 'note',
              entityId: row.id,
              title: row.title,
              body: row.body,
              isPrivateForLlm: row.isPrivateForLlm,
            ),
          );
        case LlmContextEntityType.task:
          final row = tasksById[ref.id];
          if (row == null) continue;
          items.add(
            LlmContextItem(
              entityType: 'task',
              entityId: row.id,
              title: row.title,
              body: row.description,
              isPrivateForLlm: row.isPrivateForLlm,
            ),
          );
        case LlmContextEntityType.idea:
          final row = ideasById[ref.id];
          if (row == null) continue;
          final title = row.content.length > 80
              ? '${row.content.substring(0, 77)}…'
              : row.content;
          items.add(
            LlmContextItem(
              entityType: 'idea',
              entityId: row.id,
              title: title,
              body: row.content,
              isPrivateForLlm: row.isPrivateForLlm,
            ),
          );
      }
    }
    return items;
  }
}
