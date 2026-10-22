import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/notes/domain/tag.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';

/// Drift-реализация [TagsRepository].
class DriftTagsRepository implements TagsRepository {
  DriftTagsRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<Tag>>> list() {
    return RepositoryGuard.guard('TagsRepository.list', () async {
      final rows = await (_db.select(
        _db.tags,
      )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
      return rows.map(_toDomain).toList();
    });
  }

  @override
  Future<Result<Tag>> create(String name) {
    return RepositoryGuard.guard('TagsRepository.create', () async {
      final normalized = _validateName(name);
      final existing = await _findByName(normalized);
      if (existing != null) return _toDomain(existing);
      final id = await _db
          .into(_db.tags)
          .insert(
            db.TagsCompanion.insert(
              name: normalized,
              createdAt: DateTime.now().toUtc(),
            ),
          );
      final row = await _find(id);
      return _toDomain(row!);
    });
  }

  @override
  Future<Result<Tag>> rename(int id, String name) {
    return RepositoryGuard.guard('TagsRepository.rename', () async {
      final normalized = _validateName(name);
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('TagsRepository: тег $id не найден');
      }
      final duplicate = await _findByName(normalized);
      if (duplicate != null && duplicate.id != id) {
        throw ValidationException(
          'TagsRepository: тег "$normalized" уже существует',
        );
      }
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        db.TagsCompanion(name: Value(normalized)),
      );
      final row = await _find(id);
      return _toDomain(row!);
    });
  }

  @override
  Future<Result<void>> delete(int id) {
    return RepositoryGuard.guard('TagsRepository.delete', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('TagsRepository: тег $id не найден');
      }
      await _db.transaction(() async {
        await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
        // Тег входит в текст FTS-записи — переиндексируем затронутые сущности.
        await rebuildSearchIndex(_db);
      });
    });
  }

  Future<db.Tag?> _find(int id) {
    return (_db.select(
      _db.tags,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<db.Tag?> _findByName(String name) async {
    final rows = await _db.select(_db.tags).get();
    for (final row in rows) {
      if (row.name.toLowerCase() == name.toLowerCase()) return row;
    }
    return null;
  }

  String _validateName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const ValidationException(
        'TagsRepository: название тега не может быть пустым',
      );
    }
    return normalized;
  }

  Tag _toDomain(db.Tag row) =>
      Tag(id: row.id, name: row.name, createdAt: row.createdAt);
}
