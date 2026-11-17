import '../../../core/result/result.dart';

/// Найденная статья/материал для сохранения в идею или заметку.
class ArticleSearchResult {
  const ArticleSearchResult({
    required this.title,
    required this.url,
    required this.source,
    this.summary = '',
    this.publishedAt,
  });

  final String title;
  final String url;
  final String source;
  final String summary;
  final DateTime? publishedAt;
}

/// Найденное изображение.
class ImageSearchResult {
  const ImageSearchResult({
    required this.title,
    required this.imageUrl,
    required this.source,
    this.pageUrl,
    this.creator,
    this.license,
    this.thumbnailUrl,
  });

  final String title;
  final String imageUrl;
  final String source;
  final String? pageUrl;
  final String? creator;
  final String? license;
  final String? thumbnailUrl;

  String get attribution {
    final parts = <String>[
      if (creator != null && creator!.trim().isNotEmpty) creator!.trim(),
      if (license != null && license!.trim().isNotEmpty) license!.trim(),
    ];
    return parts.join(' · ');
  }
}

/// Провайдер поиска статей. Реализации используют официальные/публичные API.
abstract interface class ArticleSearchProvider {
  String get name;

  Future<Result<List<ArticleSearchResult>>> search(
    String query, {
    int limit = 10,
  });
}

/// Провайдер поиска изображений (первая реализация — Openverse).
abstract interface class ImageSearchProvider {
  String get name;

  Future<Result<List<ImageSearchResult>>> search(
    String query, {
    int limit = 12,
  });
}
