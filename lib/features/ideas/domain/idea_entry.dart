import '../../../core/result/result.dart';

/// Запись дневника идей.
class IdeaEntry {
  const IdeaEntry({
    required this.id,
    required this.text,
    required this.source,
    required this.mood,
    required this.tags,
    required this.isPrivateForLlm,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final String text;
  final String? source;
  final String? mood;
  final List<String> tags;
  final bool isPrivateForLlm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// Данные для создания/полного обновления идеи.
class IdeaDraft {
  const IdeaDraft({
    required this.text,
    this.source,
    this.mood,
    this.tags = const [],
    this.isPrivateForLlm = false,
  });

  final String text;
  final String? source;
  final String? mood;
  final List<String> tags;
  final bool isPrivateForLlm;
}

abstract interface class IdeasRepository {
  Future<Result<List<IdeaEntry>>> list({
    bool includeDeleted = false,
    bool forLlm = false,
  });

  Future<Result<IdeaEntry?>> getById(int id, {bool includeDeleted = false});

  Future<Result<IdeaEntry>> create(IdeaDraft draft);

  Future<Result<IdeaEntry>> update(int id, IdeaDraft draft);

  Future<Result<void>> softDelete(int id);

  Future<Result<void>> restore(int id);
}
