/// Векторная запись RAG.
final class VectorRecord {
  const VectorRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.vector,
    this.metadata = const {},
    this.isPrivateForLlm = false,
  });

  final String id;
  final String entityType;
  final int entityId;
  final List<double> vector;
  final Map<String, Object?> metadata;

  /// Приватные записи не должны попадать в LLM-контекст.
  final bool isPrivateForLlm;
}

/// Результат поиска по векторному индексу.
final class VectorSearchHit {
  const VectorSearchHit({required this.record, required this.score});

  final VectorRecord record;
  final double score;
}

/// Абстракция векторного хранилища.
///
/// В MVP можно использовать in-memory реализацию, позже — SQLite-расширение
/// или внешний векторный индекс.
abstract interface class VectorStore {
  Future<void> upsert(VectorRecord record);

  Future<void> delete(String id);

  /// Возвращает ближайшие записи; приватные записи исключаются.
  Future<List<VectorSearchHit>> search(
    List<double> query, {
    int limit = 5,
  });
}
