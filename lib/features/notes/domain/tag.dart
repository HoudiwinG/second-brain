import '../../../core/result/result.dart';

/// Тег, общий для заметок, задач и идей.
class Tag {
  const Tag({required this.id, required this.name, required this.createdAt});

  final int id;
  final String name;
  final DateTime createdAt;
}

abstract interface class TagsRepository {
  Future<Result<List<Tag>>> list();

  Future<Result<Tag>> create(String name);

  Future<Result<Tag>> rename(int id, String name);

  Future<Result<void>> delete(int id);
}
