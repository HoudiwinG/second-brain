import 'package:http/http.dart' as http;

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/idea_search.dart';

/// Научные статьи через официальный Crossref REST API (без ключа).
class CrossrefArticleSearchProvider implements ArticleSearchProvider {
  CrossrefArticleSearchProvider({
    this.client,
    this.delay,
    this.baseUrl = 'https://api.crossref.org',
  });

  final http.Client? client;
  final Future<void> Function(Duration)? delay;
  final String baseUrl;

  @override
  String get name => 'Crossref';

  @override
  Future<Result<List<ArticleSearchResult>>> search(
    String query, {
    int limit = 10,
  }) async {
    final api = ApiClient(
      baseUrl: baseUrl,
      maxRetries: 2,
      client: client,
      delay: delay,
    );
    try {
      final safeLimit = limit.clamp(1, 20);
      final path =
          '/works?query=${Uri.encodeQueryComponent(query)}'
          '&rows=$safeLimit'
          '&select=DOI,title,URL,abstract,container-title,published-print,'
          'published-online,author';
      return await api.requestJson<List<ArticleSearchResult>>(
        method: 'GET',
        path: path,
        parse: (json) {
          if (json is! Map<String, Object?>) {
            throw const DataException('Crossref: некорректный ответ');
          }
          final message = json['message'];
          if (message is! Map<String, Object?>) {
            throw const DataException('Crossref: нет message');
          }
          final items = message['items'];
          if (items is! List) return const [];
          return [
            for (final item in items)
              if (item is Map<String, Object?>) _parseItem(item),
          ];
        },
      );
    } finally {
      api.close();
    }
  }

  ArticleSearchResult _parseItem(Map<String, Object?> item) {
    final title = _textList(item['title']);
    final doi = item['DOI'] is String ? item['DOI']! as String : '';
    final rawUrl = item['URL'] is String ? item['URL']! as String : '';
    final url = rawUrl.isNotEmpty
        ? rawUrl
        : doi.isEmpty
        ? ''
        : 'https://doi.org/$doi';
    final container = _textList(item['container-title']);
    final authors = item['author'];
    final authorNames = <String>[];
    if (authors is List) {
      for (final author in authors.take(3)) {
        if (author is Map<String, Object?>) {
          final given = author['given'] is String
              ? author['given']! as String
              : '';
          final family = author['family'] is String
              ? author['family']! as String
              : '';
          final name = '$given $family'.trim();
          if (name.isNotEmpty) authorNames.add(name);
        }
      }
    }
    final abstract = item['abstract'] is String
        ? _htmlToText(item['abstract']! as String)
        : '';
    return ArticleSearchResult(
      title: title.isEmpty ? doi : title,
      url: url.isEmpty ? 'https://doi.org/$doi' : url,
      source: container.isEmpty
          ? (authorNames.isEmpty ? 'Crossref' : authorNames.join(', '))
          : container,
      summary: abstract.length > 600
          ? '${abstract.substring(0, 600)}…'
          : abstract,
      publishedAt: _publishedAt(item),
    );
  }

  static String _textList(Object? value) {
    if (value is! List) return '';
    return value.whereType<String>().join(' ').trim();
  }

  static DateTime? _publishedAt(Map<String, Object?> item) {
    for (final key in ['published-print', 'published-online']) {
      final date = item[key];
      if (date is Map<String, Object?> && date['date-parts'] is List) {
        final parts = date['date-parts']! as List;
        if (parts.isNotEmpty && parts.first is List) {
          final values = (parts.first as List).whereType<num>().toList();
          if (values.isNotEmpty) {
            return DateTime.utc(
              values[0].toInt(),
              values.length > 1 ? values[1].toInt() : 1,
              values.length > 2 ? values[2].toInt() : 1,
            );
          }
        }
      }
    }
    return null;
  }

  static String _htmlToText(String value) => value
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Блоги/технические материалы через публичный Hacker News Algolia API.
class HackerNewsArticleSearchProvider implements ArticleSearchProvider {
  HackerNewsArticleSearchProvider({
    this.client,
    this.delay,
    this.baseUrl = 'https://hn.algolia.com/api/v1',
  });

  final http.Client? client;
  final Future<void> Function(Duration)? delay;
  final String baseUrl;

  @override
  String get name => 'Hacker News';

  @override
  Future<Result<List<ArticleSearchResult>>> search(
    String query, {
    int limit = 10,
  }) async {
    final api = ApiClient(
      baseUrl: baseUrl,
      maxRetries: 2,
      client: client,
      delay: delay,
    );
    try {
      final safeLimit = limit.clamp(1, 20);
      final path =
          '/search?query=${Uri.encodeQueryComponent(query)}'
          '&tags=story&hitsPerPage=$safeLimit';
      return await api.requestJson<List<ArticleSearchResult>>(
        method: 'GET',
        path: path,
        parse: (json) {
          if (json is! Map<String, Object?>) {
            throw const DataException('Hacker News: некорректный ответ');
          }
          final hits = json['hits'];
          if (hits is! List) return const [];
          return [
            for (final hit in hits)
              if (hit is Map<String, Object?>) _parseHit(hit),
          ];
        },
      );
    } finally {
      api.close();
    }
  }

  ArticleSearchResult _parseHit(Map<String, Object?> hit) {
    final title = hit['title'] is String ? hit['title']! as String : '';
    final objectId = hit['objectID'] is String
        ? hit['objectID']! as String
        : '';
    final url = hit['url'] is String && (hit['url']! as String).isNotEmpty
        ? hit['url']! as String
        : 'https://news.ycombinator.com/item?id=$objectId';
    final text = hit['story_text'] is String
        ? _htmlToText(hit['story_text']! as String)
        : '';
    final createdAt = hit['created_at'] is String
        ? DateTime.tryParse(hit['created_at']! as String)?.toUtc()
        : null;
    return ArticleSearchResult(
      title: title.isEmpty ? 'Hacker News' : title,
      url: url,
      source: 'Hacker News',
      summary: text.length > 600 ? '${text.substring(0, 600)}…' : text,
      publishedAt: createdAt,
    );
  }

  static String _htmlToText(String value) => value
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Объединяет научные и блоговые источники, не теряя результаты одного
/// провайдера при ошибке другого.
class ArticleSearchService {
  ArticleSearchService(this.providers);

  final List<ArticleSearchProvider> providers;

  Future<Result<List<ArticleSearchResult>>> search(
    String query, {
    int limit = 10,
  }) async {
    final text = query.trim();
    if (text.isEmpty) {
      return const Result.failure(
        ValidationException('ArticleSearch: пустой запрос'),
      );
    }
    final merged = <ArticleSearchResult>[];
    final urls = <String>{};
    final errors = <AppException>[];
    for (final provider in providers) {
      final result = await provider.search(text, limit: limit);
      result.when(
        success: (items) {
          for (final item in items) {
            if (urls.add(item.url)) merged.add(item);
          }
        },
        failure: errors.add,
      );
    }
    if (merged.isEmpty && errors.isNotEmpty) {
      return Result.failure(errors.first);
    }
    return Result.success(merged.take(limit).toList());
  }
}
