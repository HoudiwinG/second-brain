import 'package:drift/drift.dart';

import '../db/app_database.dart' as db;
import '../repositories/tag_utils.dart';

/// Константы типов сущностей FTS-индекса.
abstract final class SearchEntityTypes {
  static const String note = 'note';
  static const String task = 'task';
  static const String idea = 'idea';
  static const String finance = 'finance';
  static const String learning = 'learning';
  static const String chat = 'chat';
  static const String mail = 'mail';
}

/// Удаляет несколько записей индекса (например, письма удалённого ящика).
Future<void> removeSearchEntries(
  db.AppDatabase database,
  String entityType,
  Iterable<int> entityIds,
) async {
  for (final id in entityIds) {
    await removeSearchEntry(database, entityType, id);
  }
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

Future<void> indexLearningTrack(db.AppDatabase database, int trackId) async {
  final row = await (database.select(
    database.learningTracks,
  )..where((t) => t.id.equals(trackId))).getSingleOrNull();
  if (row == null || row.deletedAt != null) {
    await removeSearchEntry(database, SearchEntityTypes.learning, trackId);
    return;
  }
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.learning,
    entityId: trackId,
    title: row.title,
    body: '${row.goal}\n${row.roadmapJson}\n${row.customFieldsJson}',
    tags: '',
    isPrivateForLlm: row.isPrivateForLlm,
  );
}

/// Индексирует тред целиком: поиск находит содержимое любого сообщения.
Future<void> indexChatThread(db.AppDatabase database, int threadId) async {
  final thread = await (database.select(
    database.chatThreads,
  )..where((t) => t.id.equals(threadId))).getSingleOrNull();
  if (thread == null) {
    await removeSearchEntry(database, SearchEntityTypes.chat, threadId);
    return;
  }
  final messages = await (database.select(
    database.chatMessages,
  )..where((m) => m.threadId.equals(threadId))).get();
  final body = messages
      .map((m) => m.content)
      .where((c) => c.isNotEmpty)
      .join('\n');
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.chat,
    entityId: threadId,
    title: thread.title,
    body: body,
    tags: '',
    isPrivateForLlm: messages.any((m) => m.isPrivateForLlm),
  );
}

Future<void> indexMailMessage(db.AppDatabase database, int messageId) async {
  final row = await (database.select(
    database.mailMessages,
  )..where((m) => m.id.equals(messageId))).getSingleOrNull();
  if (row == null) {
    await removeSearchEntry(database, SearchEntityTypes.mail, messageId);
    return;
  }
  await upsertSearchEntry(
    database,
    entityType: SearchEntityTypes.mail,
    entityId: messageId,
    title: row.subject.isEmpty ? row.fromAddress : row.subject,
    body: '${row.fromAddress}\n${row.snippet}\n${row.body}',
    tags: '',
    isPrivateForLlm: row.isPrivateForLlm,
  );
}

/// Версия структуры/содержимого индекса. Меняется при расширении набора
/// сущностей; при несовпадении выполняется однократный rebuild.
const String searchIndexVersion = '2';
const String searchIndexVersionKey = 'search.index.version';

/// Однократный backfill для уже существующих БД без миграции схемы.
Future<void> ensureSearchIndexVersion(db.AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT value FROM app_settings WHERE key = ?',
        variables: [Variable.withString(searchIndexVersionKey)],
      )
      .get();
  if (rows.isNotEmpty &&
      rows.first.read<String>('value') == searchIndexVersion) {
    return;
  }
  await rebuildSearchIndex(database);
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
  final tracks = await database.select(database.learningTracks).get();
  for (final row in tracks) {
    if (row.deletedAt == null) await indexLearningTrack(database, row.id);
  }
  final threads = await database.select(database.chatThreads).get();
  for (final row in threads) {
    await indexChatThread(database, row.id);
  }
  final mail = await database.select(database.mailMessages).get();
  for (final row in mail) {
    await indexMailMessage(database, row.id);
  }
  await database
      .into(database.appSettings)
      .insertOnConflictUpdate(
        db.AppSettingsCompanion.insert(
          key: searchIndexVersionKey,
          value: searchIndexVersion,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}
