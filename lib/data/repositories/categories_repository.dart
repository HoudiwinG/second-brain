import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/notes/domain/category.dart';
import '../db/app_database.dart' as db;
import 'repository_guard.dart';

/// Drift-реализация [CategoriesRepository].
class DriftCategoriesRepository implements CategoriesRepository {
  DriftCategoriesRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<Category>>> list() {
    return RepositoryGuard.guard('CategoriesRepository.list', () async {
      final rows = await (_db.select(
        _db.categories,
      )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
      return rows.map(_toDomain).toList();
    });
  }

  @override
  Future<Result<Category?>> getById(int id) {
    return RepositoryGuard.guard('CategoriesRepository.getById', () async {
      final row = await _find(id);
      return row == null ? null : _toDomain(row);
    });
  }

  @override
  Future<Result<Category>> create({required String name, int? parentId}) {
    return RepositoryGuard.guard('CategoriesRepository.create', () async {
      final normalized = _validateName(name);
      if (parentId != null) await _requireCategory(parentId);
      final now = DateTime.now().toUtc();
      final id = await _db
          .into(_db.categories)
          .insert(
            db.CategoriesCompanion.insert(
              name: normalized,
              parentId: Value(parentId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final row = await _find(id);
      return _toDomain(row!);
    });
  }

  @override
  Future<Result<Category>> update(
    int id, {
    required String name,
    int? parentId,
  }) {
    return RepositoryGuard.guard('CategoriesRepository.update', () async {
      final normalized = _validateName(name);
      final current = await _find(id);
      if (current == null) {
        throw ValidationException(
          'CategoriesRepository: категория $id не найдена',
        );
      }
      if (parentId != null) {
        if (parentId == id) {
          throw const ValidationException(
            'CategoriesRepository: категория не может быть родителем самой себе',
          );
        }
        await _requireCategory(parentId);
        await _ensureNoCycle(id, parentId);
      }
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        db.CategoriesCompanion(
          name: Value(normalized),
          parentId: Value(parentId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      final row = await _find(id);
      return _toDomain(row!);
    });
  }

  @override
  Future<Result<void>> delete(int id) {
    return RepositoryGuard.guard('CategoriesRepository.delete', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException(
          'CategoriesRepository: категория $id не найдена',
        );
      }
      // FK ON DELETE SET NULL обнуляет category_id у заметок и parent_id у детей.
      await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<db.Category?> _find(int id) {
    return (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> _requireCategory(int id) async {
    if (await _find(id) == null) {
      throw ValidationException('CategoriesRepository: родитель $id не найден');
    }
  }

  Future<void> _ensureNoCycle(int id, int newParentId) async {
    int? cursor = newParentId;
    while (cursor != null) {
      final row = await _find(cursor);
      if (row == null) return;
      if (row.id == id) {
        throw const ValidationException(
          'CategoriesRepository: иерархия категорий образует цикл',
        );
      }
      cursor = row.parentId;
    }
  }

  String _validateName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const ValidationException(
        'CategoriesRepository: название категории не может быть пустым',
      );
    }
    return normalized;
  }

  Category _toDomain(db.Category row) => Category(
    id: row.id,
    name: row.name,
    parentId: row.parentId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
