import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/ideas/domain/idea_entry.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';
import 'tag_utils.dart';

/// Drift-реализация [IdeasRepository].
class DriftIdeasRepository implements IdeasRepository {
  DriftIdeasRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<IdeaEntry>>> list({
    bool includeDeleted = false,
    bool forLlm = false,
  }) {
    return RepositoryGuard.guard('IdeasRepository.list', () async {
      final query = _db.select(_db.ideaEntries);
      if (!includeDeleted) {
        query.where((t) => t.deletedAt.isNull());
      }
      if (forLlm) {
        query.where((t) => t.isPrivateForLlm.equals(false));
      }
      query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      final rows = await query.get();
      return [
        for (final row in rows) _toDomain(row, await tagsForIdea(_db, row.id)),
      ];
    });
  }

  @override
  Future<Result<IdeaEntry?>> getById(int id, {bool includeDeleted = false}) {
    return RepositoryGuard.guard('IdeasRepository.getById', () async {
      final row = await _find(id, includeDeleted: includeDeleted);
      if (row == null) return null;
      return _toDomain(row, await tagsForIdea(_db, id));
    });
  }

  @override
  Future<Result<IdeaEntry>> create(IdeaDraft draft) {
    return RepositoryGuard.guard('IdeasRepository.create', () async {
      final text = draft.text.trim();
      if (text.isEmpty) {
        throw const ValidationException(
          'IdeasRepository: текст идеи не может быть пустым',
        );
      }
      final now = DateTime.now().toUtc();
      late IdeaEntry created;
      await _db.transaction(() async {
        final id = await _db
            .into(_db.ideaEntries)
            .insert(
              db.IdeaEntriesCompanion.insert(
                content: text,
                source: Value(draft.source?.trim()),
                mood: Value(draft.mood?.trim()),
                isPrivateForLlm: Value(draft.isPrivateForLlm),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await replaceIdeaTags(_db, id, draft.tags);
        await indexIdea(_db, id);
        final row = await _find(id);
        created = _toDomain(row!, await tagsForIdea(_db, id));
      });
      return created;
    });
  }

  @override
  Future<Result<IdeaEntry>> update(int id, IdeaDraft draft) {
    return RepositoryGuard.guard('IdeasRepository.update', () async {
      final text = draft.text.trim();
      if (text.isEmpty) {
        throw const ValidationException(
          'IdeasRepository: текст идеи не может быть пустым',
        );
      }
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('IdeasRepository: идея $id не найдена');
      }
      final now = DateTime.now().toUtc();
      late IdeaEntry updated;
      await _db.transaction(() async {
        await (_db.update(
          _db.ideaEntries,
        )..where((t) => t.id.equals(id))).write(
          db.IdeaEntriesCompanion(
            content: Value(text),
            source: Value(draft.source?.trim()),
            mood: Value(draft.mood?.trim()),
            isPrivateForLlm: Value(draft.isPrivateForLlm),
            updatedAt: Value(now),
          ),
        );
        await replaceIdeaTags(_db, id, draft.tags);
        await indexIdea(_db, id);
        final row = await _find(id);
        updated = _toDomain(row!, await tagsForIdea(_db, id));
      });
      return updated;
    });
  }

  @override
  Future<Result<void>> softDelete(int id) {
    return RepositoryGuard.guard('IdeasRepository.softDelete', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('IdeasRepository: идея $id не найдена');
      }
      final now = DateTime.now().toUtc();
      await _db.transaction(() async {
        await (_db.update(
          _db.ideaEntries,
        )..where((t) => t.id.equals(id))).write(
          db.IdeaEntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        await indexIdea(_db, id);
      });
    });
  }

  @override
  Future<Result<void>> restore(int id) {
    return RepositoryGuard.guard('IdeasRepository.restore', () async {
      final current = await _find(id, includeDeleted: true);
      if (current == null) {
        throw ValidationException('IdeasRepository: идея $id не найдена');
      }
      await _db.transaction(() async {
        await (_db.update(
          _db.ideaEntries,
        )..where((t) => t.id.equals(id))).write(
          db.IdeaEntriesCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexIdea(_db, id);
      });
    });
  }

  Future<db.IdeaEntry?> _find(int id, {bool includeDeleted = false}) {
    final query = _db.select(_db.ideaEntries)..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  IdeaEntry _toDomain(db.IdeaEntry row, List<String> tags) => IdeaEntry(
    id: row.id,
    text: row.content,
    source: row.source,
    mood: row.mood,
    tags: List.unmodifiable(tags),
    isPrivateForLlm: row.isPrivateForLlm,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
