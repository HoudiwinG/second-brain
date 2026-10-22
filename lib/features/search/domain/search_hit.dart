import '../../../core/result/result.dart';

/// Тип сущности в полнотекстовом индексе.
enum SearchEntityType {
  note,
  task,
  idea,
  finance;

  static SearchEntityType fromDb(String value) => values.firstWhere(
    (t) => t.name == value,
    orElse: () => SearchEntityType.note,
  );
}

/// Результат FTS-поиска с подсветкой фрагмента.
class SearchHit {
  const SearchHit({
    required this.type,
    required this.entityId,
    required this.title,
    required this.snippet,
    required this.tags,
    required this.isPrivateForLlm,
  });

  final SearchEntityType type;
  final int entityId;
  final String title;
  final String snippet;
  final List<String> tags;
  final bool isPrivateForLlm;
}

abstract interface class SearchRepository {
  /// Поиск по FTS5. При [forLlm] = true приватные записи исключаются.
  Future<Result<List<SearchHit>>> search(
    String query, {
    bool forLlm = false,
    int limit = 50,
  });

  /// Полная переиндексация (после импорта или ручного изменения БД).
  Future<Result<void>> rebuild();
}
