import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/chat/domain/chat_message.dart';
import '../../features/chat/domain/chat_thread.dart';
import '../../features/llm/domain/llm_message.dart';
import '../db/app_database.dart' as db;
import 'repository_guard.dart';

/// Доступ к офлайн-истории чата.
abstract interface class ChatRepository {
  Future<Result<List<ChatThread>>> listThreads({bool includeArchived = false});

  Future<Result<ChatThread?>> getThread(int id);

  Future<Result<ChatThread>> createThread(ChatThreadDraft draft);

  Future<Result<ChatThread>> renameThread(int id, String title);

  Future<Result<void>> deleteThread(int id);

  Future<Result<List<ChatMessage>>> listMessages(int threadId);

  Future<Result<ChatMessage>> appendMessage(ChatMessageDraft draft);
}

/// Drift-реализация истории чата.
final class DriftChatRepository implements ChatRepository {
  DriftChatRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<ChatThread>>> listThreads({
    bool includeArchived = false,
  }) {
    return RepositoryGuard.guard('ChatRepository.listThreads', () async {
      final query = _db.select(_db.chatThreads)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      if (!includeArchived) {
        query.where((t) => t.archivedAt.isNull());
      }
      final rows = await query.get();
      return [for (final row in rows) _thread(row)];
    });
  }

  @override
  Future<Result<ChatThread?>> getThread(int id) {
    return RepositoryGuard.guard('ChatRepository.getThread', () async {
      final row = await (_db.select(
        _db.chatThreads,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _thread(row);
    });
  }

  @override
  Future<Result<ChatThread>> createThread(ChatThreadDraft draft) {
    return RepositoryGuard.guard('ChatRepository.createThread', () async {
      final title = draft.title.trim();
      if (title.isEmpty) {
        throw const ValidationException(
          'ChatRepository: заголовок треда не может быть пустым',
        );
      }
      if (draft.model.trim().isEmpty) {
        throw const ValidationException('ChatRepository: не выбрана модель');
      }
      final now = DateTime.now().toUtc();
      final id = await _db
          .into(_db.chatThreads)
          .insert(
            db.ChatThreadsCompanion.insert(
              title: title,
              providerConfigId: Value(draft.providerConfigId),
              model: draft.model.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final row = await (_db.select(
        _db.chatThreads,
      )..where((t) => t.id.equals(id))).getSingle();
      return _thread(row);
    });
  }

  @override
  Future<Result<ChatThread>> renameThread(int id, String title) {
    return RepositoryGuard.guard('ChatRepository.renameThread', () async {
      final normalized = title.trim();
      if (normalized.isEmpty) {
        throw const ValidationException(
          'ChatRepository: заголовок треда не может быть пустым',
        );
      }
      final updated = await (_db.update(
        _db.chatThreads,
      )..where((t) => t.id.equals(id))).write(
        db.ChatThreadsCompanion(
          title: Value(normalized),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      if (updated == 0) {
        throw ValidationException('ChatRepository: тред $id не найден');
      }
      final row = await (_db.select(
        _db.chatThreads,
      )..where((t) => t.id.equals(id))).getSingle();
      return _thread(row);
    });
  }

  @override
  Future<Result<void>> deleteThread(int id) {
    return RepositoryGuard.guard('ChatRepository.deleteThread', () async {
      await (_db.delete(
        _db.chatThreads,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<Result<List<ChatMessage>>> listMessages(int threadId) {
    return RepositoryGuard.guard('ChatRepository.listMessages', () async {
      final rows =
          await (_db.select(_db.chatMessages)
                ..where((m) => m.threadId.equals(threadId))
                ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
              .get();
      return [for (final row in rows) _message(row)];
    });
  }

  @override
  Future<Result<ChatMessage>> appendMessage(ChatMessageDraft draft) {
    return RepositoryGuard.guard('ChatRepository.appendMessage', () async {
      if (draft.content.isEmpty && draft.errorCode == null) {
        throw const ValidationException(
          'ChatRepository: пустое сообщение не сохраняется',
        );
      }
      final now = DateTime.now().toUtc();
      final id = await _db
          .into(_db.chatMessages)
          .insert(
            db.ChatMessagesCompanion.insert(
              threadId: draft.threadId,
              role: draft.role.dbValue,
              content: draft.content,
              promptTokens: Value(draft.promptTokens),
              completionTokens: Value(draft.completionTokens),
              errorCode: Value(draft.errorCode),
              createdAt: now,
            ),
          );
      await (_db.update(
        _db.chatThreads,
      )..where((t) => t.id.equals(draft.threadId))).write(
        db.ChatThreadsCompanion(updatedAt: Value(now)),
      );
      final row = await (_db.select(
        _db.chatMessages,
      )..where((m) => m.id.equals(id))).getSingle();
      return _message(row);
    });
  }

  static ChatThread _thread(db.ChatThread row) => ChatThread(
    id: row.id,
    title: row.title,
    providerConfigId: row.providerConfigId,
    model: row.model,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    archivedAt: row.archivedAt,
  );

  static ChatMessage _message(db.ChatMessage row) => ChatMessage(
    id: row.id,
    threadId: row.threadId,
    role: LlmRole.fromDb(row.role),
    content: row.content,
    promptTokens: row.promptTokens,
    completionTokens: row.completionTokens,
    errorCode: row.errorCode,
    createdAt: row.createdAt,
  );
}
