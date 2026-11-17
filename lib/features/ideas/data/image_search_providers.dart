import 'package:http/http.dart' as http;

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/idea_search.dart';

/// Поиск изображений через публичный Openverse API.
class OpenverseImageSearchProvider implements ImageSearchProvider {
  OpenverseImageSearchProvider({
    this.client,
    this.delay,
    this.baseUrl = 'https://api.openverse.org/v1',
  });

  final http.Client? client;
  final Future<void> Function(Duration)? delay;
  final String baseUrl;

  @override
  String get name => 'Openverse';

  @override
  Future<Result<List<ImageSearchResult>>> search(
    String query, {
    int limit = 12,
  }) async {
    final text = query.trim();
    if (text.isEmpty) {
      return const Result.failure(
        ValidationException('ImageSearch: пустой запрос'),
      );
    }
    final api = ApiClient(
      baseUrl: baseUrl,
      maxRetries: 2,
      headersProvider: () => const {'User-Agent': 'SecondBrain/1.0'},
      client: client,
      delay: delay,
    );
    try {
      final safeLimit = limit.clamp(1, 24);
      final path =
          '/images?q=${Uri.encodeQueryComponent(text)}'
          '&page_size=$safeLimit';
      return await api.requestJson<List<ImageSearchResult>>(
        method: 'GET',
        path: path,
        parse: (json) {
          if (json is! Map<String, Object?>) {
            throw const DataException('Openverse: некорректный ответ');
          }
          final results = json['results'];
          if (results is! List) return const [];
          return [
            for (final item in results)
              if (item is Map<String, Object?> &&
                  item['url'] is String &&
                  (item['url']! as String).isNotEmpty)
                _parse(item),
          ];
        },
      );
    } finally {
      api.close();
    }
  }

  ImageSearchResult _parse(Map<String, Object?> item) {
    final title = item['title'] is String
        ? (item['title']! as String).trim()
        : '';
    final imageUrl = item['url'] is String ? item['url']! as String : '';
    final pageUrl = item['foreign_landing_url'] is String
        ? item['foreign_landing_url']! as String
        : null;
    final creator = item['creator'] is String
        ? item['creator']! as String
        : null;
    final license = item['license'] is String
        ? item['license']! as String
        : null;
    final thumbnail = item['thumbnail'] is String
        ? item['thumbnail']! as String
        : null;
    return ImageSearchResult(
      title: title.isEmpty ? 'Openverse image' : title,
      imageUrl: imageUrl,
      source: 'Openverse',
      pageUrl: pageUrl,
      creator: creator,
      license: license,
      thumbnailUrl: thumbnail,
    );
  }
}

class ImageSearchService {
  ImageSearchService(this.provider);

  final ImageSearchProvider provider;

  Future<Result<List<ImageSearchResult>>> search(
    String query, {
    int limit = 12,
  }) => provider.search(query, limit: limit);
}
