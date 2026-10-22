import '../db/app_database.dart' as db;
import '../repositories/tag_utils.dart';

/// Константы типов сущностей FTS-индекса.
abstract final class SearchEntityTypes {
  static const String note = 'note';
  static const String task = 'task';
  static const String idea = 'idea';
  static const String finance = 'finance';
}

Future<void> removeSearchEntry(
  db.AppDatabase database,
  String entityType,
  int entityId,
) async {
  await database.customStatement(
    'DELETE FROM search_index WHERE entity_type = ? AND entity_id = ?',
    [entityType, entityId],
  );
}

Future<void> upsertSearchEntry(
  db.AppDatabase database, {
  required String entityType,
  required int entityId,
  required String title,
  required String body,
  required String tags,
  required bool isPrivateForLlm,
}) async {
  await removeSearchEntry(database, entityType, entityId);
  await database.customStatement(
    'INSERT INTO search_index '
    '(entity_type, entity_id, title, body, tags, is_private) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    [entityType, entityId, title, body, tags, isPrivateForLlm ? '1' : '0'],
  );
}

Future<void> indexNote(db.AppDatabase database, int noteId) async {
  final row = await (database.select(
    database.notes,
  )..where((t) => t.id.equals(noteId))).getSingleOrNull();
  if (row == null || row.deletedAt != null) {
    await removeSearchEntry(database, SearchEntityTypes.note, noteId);
    return;
  }
  final tags = await tagsForNote(database, noteId);
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.note,
    entityId: noteId,
    title: row.title,
    body: row.body,
    tags: tags.join(' '),
    isPrivateForLlm: row.isPrivateForLlm,
  );
}

Future<void> indexTask(db.AppDatabase database, int taskId) async {
  final row = await (database.select(
    database.tasks,
  )..where((t) => t.id.equals(taskId))).getSingleOrNull();
  if (row == null || row.deletedAt != null) {
    await removeSearchEntry(database, SearchEntityTypes.task, taskId);
    return;
  }
  final tags = await tagsForTask(database, taskId);
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.task,
    entityId: taskId,
    title: row.title,
    body: row.description,
    tags: tags.join(' '),
    isPrivateForLlm: row.isPrivateForLlm,
  );
}

Future<void> indexIdea(db.AppDatabase database, int ideaId) async {
  final row = await (database.select(
    database.ideaEntries,
  )..where((t) => t.id.equals(ideaId))).getSingleOrNull();
  if (row == null || row.deletedAt != null) {
    await removeSearchEntry(database, SearchEntityTypes.idea, ideaId);
    return;
  }
  final tags = await tagsForIdea(database, ideaId);
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.idea,
    entityId: ideaId,
    title: row.content.split('\n').first,
    body: row.content,
    tags: tags.join(' '),
    isPrivateForLlm: row.isPrivateForLlm,
  );
}

Future<void> indexFinance(db.AppDatabase database, int transactionId) async {
  final row = await (database.select(
    database.financeTransactions,
  )..where((t) => t.id.equals(transactionId))).getSingleOrNull();
  if (row == null || row.deletedAt != null) {
    await removeSearchEntry(database, SearchEntityTypes.finance, transactionId);
    return;
  }
  final title = row.category ?? row.note ?? row.type;
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.finance,
    entityId: transactionId,
    title: title,
    body: [
      row.note,
      row.account,
      row.category,
      row.type,
      row.amount.toStringAsFixed(2),
      row.currency,
    ].whereType<String>().join(' '),
    tags: '',
    isPrivateForLlm: row.isPrivateForLlm,
  );
}

/// Полная переиндексация всех сущностей.
Future<void> rebuildSearchIndex(db.AppDatabase database) async {
  await database.customStatement('DELETE FROM search_index');

  final notes = await database.select(database.notes).get();
  for (final row in notes) {
    if (row.deletedAt == null) await indexNote(database, row.id);
  }
  final tasks = await database.select(database.tasks).get();
  for (final row in tasks) {
    if (row.deletedAt == null) await indexTask(database, row.id);
  }
  final ideas = await database.select(database.ideaEntries).get();
  for (final row in ideas) {
    if (row.deletedAt == null) await indexIdea(database, row.id);
  }
  final finance = await database.select(database.financeTransactions).get();
  for (final row in finance) {
    if (row.deletedAt == null) await indexFinance(database, row.id);
  }
}
