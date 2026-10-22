import 'package:drift/drift.dart';

import '../db/app_database.dart' as db;

/// Нормализует тег: trim и удаление пустых значений.
String? normalizeTagName(String raw) {
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

/// Возвращает/создаёт теги по именам (регистронезависимый поиск).
Future<List<db.Tag>> resolveTags(
  db.AppDatabase database,
  Iterable<String> names,
) async {
  final result = <db.Tag>[];
  for (final raw in names) {
    final name = normalizeTagName(raw);
    if (name == null) continue;
    if (result.any((t) => t.name.toLowerCase() == name.toLowerCase())) continue;

    final existing = (await database.select(database.tags).get())
        .where((t) => t.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      result.add(existing);
      continue;
    }
    final id = await database
        .into(database.tags)
        .insert(
          db.TagsCompanion.insert(
            name: name,
            createdAt: DateTime.now().toUtc(),
          ),
        );
    final inserted = await (database.select(
      database.tags,
    )..where((t) => t.id.equals(id))).getSingle();
    result.add(inserted);
  }
  return result;
}

Future<void> replaceNoteTags(
  db.AppDatabase database,
  int noteId,
  List<String> tags,
) async {
  await (database.delete(
    database.noteTags,
  )..where((t) => t.noteId.equals(noteId))).go();
  final resolved = await resolveTags(database, tags);
  for (final tag in resolved) {
    await database
        .into(database.noteTags)
        .insert(
          db.NoteTagsCompanion.insert(noteId: noteId, tagId: tag.id),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

Future<void> replaceTaskTags(
  db.AppDatabase database,
  int taskId,
  List<String> tags,
) async {
  await (database.delete(
    database.taskTags,
  )..where((t) => t.taskId.equals(taskId))).go();
  final resolved = await resolveTags(database, tags);
  for (final tag in resolved) {
    await database
        .into(database.taskTags)
        .insert(
          db.TaskTagsCompanion.insert(taskId: taskId, tagId: tag.id),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

Future<void> replaceIdeaTags(
  db.AppDatabase database,
  int ideaId,
  List<String> tags,
) async {
  await (database.delete(
    database.ideaTags,
  )..where((t) => t.ideaId.equals(ideaId))).go();
  final resolved = await resolveTags(database, tags);
  for (final tag in resolved) {
    await database
        .into(database.ideaTags)
        .insert(
          db.IdeaTagsCompanion.insert(ideaId: ideaId, tagId: tag.id),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

Future<List<String>> tagsForNote(db.AppDatabase database, int noteId) async {
  final query = database.select(database.noteTags).join([
    innerJoin(
      database.tags,
      database.tags.id.equalsExp(database.noteTags.tagId),
    ),
  ])..where(database.noteTags.noteId.equals(noteId));
  final rows = await query.get();
  return rows.map((row) => row.readTable(database.tags).name).toList()..sort();
}

Future<List<String>> tagsForTask(db.AppDatabase database, int taskId) async {
  final query = database.select(database.taskTags).join([
    innerJoin(
      database.tags,
      database.tags.id.equalsExp(database.taskTags.tagId),
    ),
  ])..where(database.taskTags.taskId.equals(taskId));
  final rows = await query.get();
  return rows.map((row) => row.readTable(database.tags).name).toList()..sort();
}

Future<List<String>> tagsForIdea(db.AppDatabase database, int ideaId) async {
  final query = database.select(database.ideaTags).join([
    innerJoin(
      database.tags,
      database.tags.id.equalsExp(database.ideaTags.tagId),
    ),
  ])..where(database.ideaTags.ideaId.equals(ideaId));
  final rows = await query.get();
  return rows.map((row) => row.readTable(database.tags).name).toList()..sort();
}
