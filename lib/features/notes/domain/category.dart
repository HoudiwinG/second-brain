import '../../../core/result/result.dart';

/// Категория заметок; [parentId] задаёт иерархию.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class CategoriesRepository {
  Future<Result<List<Category>>> list();

  Future<Result<Category?>> getById(int id);

  Future<Result<Category>> create({required String name, int? parentId});

  Future<Result<Category>> update(
    int id, {
    required String name,
    int? parentId,
  });

  /// Удаляет категорию; у заметок category_id становится NULL (FK ON DELETE SET NULL).
  Future<Result<void>> delete(int id);
}
