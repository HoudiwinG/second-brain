import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/notes/domain/note.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';
import 'tag_utils.dart';

/// Drift-реализация [NotesRepository].
class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<Note>>> list({
    bool includeDeleted = false,
    bool forLlm = false,
  }) {
    return RepositoryGuard.guard('NotesRepository.list', () async {
      final query = _db.select(_db.notes);
      if (!includeDeleted) {
        query.where((t) => t.deletedAt.isNull());
      }
      if (forLlm) {
        query.where((t) => t.isPrivateForLlm.equals(false));
      }
      query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      final rows = await query.get();
      return [
        for (final row in rows) _toDomain(row, await tagsForNote(_db, row.id)),
      ];
    });
  }

  @override
  Future<Result<Note?>> getById(int id, {bool includeDeleted = false}) {
    return RepositoryGuard.guard('NotesRepository.getById', () async {
      final row = await _find(id, includeDeleted: includeDeleted);
      if (row == null) return null;
      return _toDomain(row, await tagsForNote(_db, id));
    });
  }

  @override
  Future<Result<Note>> create(NoteDraft draft) {
    return RepositoryGuard.guard('NotesRepository.create', () async {
      final title = draft.title.trim();
      if (title.isEmpty) {
        throw const ValidationException(
          'NotesRepository: заголовок заметки не может быть пустым',
        );
      }
      final now = DateTime.now().toUtc();
      late Note created;
      await _db.transaction(() async {
        final id = await _db
            .into(_db.notes)
            .insert(
              db.NotesCompanion.insert(
                title: title,
                body: Value(draft.body),
                categoryId: Value(draft.categoryId),
                isPrivateForLlm: Value(draft.isPrivateForLlm),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await replaceNoteTags(_db, id, draft.tags);
        await indexNote(_db, id);
        final row = await _find(id);
        created = _toDomain(row!, await tagsForNote(_db, id));
      });
      return created;
    });
  }

  @override
  Future<Result<Note>> update(int id, NoteDraft draft) {
    return RepositoryGuard.guard('NotesRepository.update', () async {
      final title = draft.title.trim();
      if (title.isEmpty) {
        throw const ValidationException(
          'NotesRepository: заголовок заметки не может быть пустым',
        );
      }
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('NotesRepository: заметка $id не найдена');
      }
      final now = DateTime.now().toUtc();
      late Note updated;
      await _db.transaction(() async {
        await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
          db.NotesCompanion(
            title: Value(title),
            body: Value(draft.body),
            categoryId: Value(draft.categoryId),
            isPrivateForLlm: Value(draft.isPrivateForLlm),
            updatedAt: Value(now),
          ),
        );
        await replaceNoteTags(_db, id, draft.tags);
        await indexNote(_db, id);
        final row = await _find(id);
        updated = _toDomain(row!, await tagsForNote(_db, id));
      });
      return updated;
    });
  }

  @override
  Future<Result<void>> softDelete(int id) {
    return RepositoryGuard.guard('NotesRepository.softDelete', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('NotesRepository: заметка $id не найдена');
      }
      final now = DateTime.now().toUtc();
      await _db.transaction(() async {
        await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
          db.NotesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        await indexNote(_db, id);
      });
    });
  }

  @override
  Future<Result<void>> restore(int id) {
    return RepositoryGuard.guard('NotesRepository.restore', () async {
      final current = await _find(id, includeDeleted: true);
      if (current == null) {
        throw ValidationException('NotesRepository: заметка $id не найдена');
      }
      await _db.transaction(() async {
        await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
          db.NotesCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexNote(_db, id);
      });
    });
  }

  Future<db.Note?> _find(int id, {bool includeDeleted = false}) {
    final query = _db.select(_db.notes)..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  Note _toDomain(db.Note row, List<String> tags) => Note(
    id: row.id,
    title: row.title,
    body: row.body,
    categoryId: row.categoryId,
    tags: List.unmodifiable(tags),
    isPrivateForLlm: row.isPrivateForLlm,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
