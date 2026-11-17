import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/features/ideas/data/article_search_providers.dart';
import 'package:second_brain/features/ideas/data/image_search_providers.dart';
import 'package:second_brain/features/ideas/domain/idea_search.dart';

void main() {
  test('Crossref парсит научную статью', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/works');
      expect(request.url.queryParameters['query'], 'quantum');
      return http.Response(
        '{"message":{"items":[{'
        '"DOI":"10.1/test",'
        '"title":["Quantum <i>idea</i> &amp; more"],'
        '"URL":"https://doi.org/10.1/test",'
        '"abstract":"<jats:p>Short abstract</jats:p>",'
        '"container-title":["Journal"],'
        '"author":[{"given":"A","family":"Author"}],'
        '"published-print":{"date-parts":[[2026,5,1]]}'
        '}]}}',
        200,
      );
    });
    final provider = CrossrefArticleSearchProvider(client: client);

    final result = await provider.search('quantum');

    final items = (result as Success<List<ArticleSearchResult>>).value;
    expect(items.single.title, 'Quantum idea & more');
    expect(items.single.source, 'Journal');
    expect(items.single.summary, 'Short abstract');
    expect(items.single.publishedAt, DateTime.utc(2026, 5, 1));
  });

  test('Hacker News парсит блоговые материалы', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/search');
      return http.Response(
        '{"hits":[{'
        '"title":"A blog post",'
        '"url":"https://example.com/post",'
        '"story_text":"Some text",'
        '"created_at":"2026-05-01T10:00:00Z",'
        '"objectID":"123"'
        '}]}',
        200,
      );
    });
    final provider = HackerNewsArticleSearchProvider(client: client);

    final result = await provider.search('blog');

    final items = (result as Success<List<ArticleSearchResult>>).value;
    expect(items.single.url, 'https://example.com/post');
    expect(items.single.source, 'Hacker News');
    expect(items.single.summary, 'Some text');
  });

  test('ArticleSearchService объединяет источники и убирает дубли', () async {
    final service = ArticleSearchService([
      _FakeArticleProvider([
        const ArticleSearchResult(title: 'One', url: 'https://a', source: 'A'),
        const ArticleSearchResult(title: 'Two', url: 'https://b', source: 'B'),
      ]),
      _FakeArticleProvider([
        const ArticleSearchResult(
          title: 'Duplicate',
          url: 'https://a',
          source: 'C',
        ),
        const ArticleSearchResult(
          title: 'Three',
          url: 'https://c',
          source: 'D',
        ),
      ]),
    ]);

    final result = await service.search('topic');

    final items = (result as Success<List<ArticleSearchResult>>).value;
    expect(items.map((item) => item.url).toSet(), {
      'https://a',
      'https://b',
      'https://c',
    });
  });

  test('ArticleSearchService не вытесняет второй источник лимитом', () async {
    final service = ArticleSearchService([
      _FakeArticleProvider([
        for (var i = 0; i < 10; i++)
          ArticleSearchResult(
            title: 'Crossref $i',
            url: 'https://crossref/$i',
            source: 'Crossref',
          ),
      ]),
      _FakeArticleProvider([
        const ArticleSearchResult(
          title: 'HN story',
          url: 'https://hn/1',
          source: 'Hacker News',
        ),
      ]),
    ]);

    final result = await service.search('topic');

    final items = (result as Success<List<ArticleSearchResult>>).value;
    expect(items, hasLength(10));
    expect(items.any((item) => item.source == 'Hacker News'), isTrue);
  });

  test('Openverse парсит изображение и атрибуцию', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/images');
      return http.Response(
        '{"results":[{'
        '"title":"A photo",'
        '"url":"https://img/1.jpg",'
        '"foreign_landing_url":"https://page/1",'
        '"creator":"Photographer",'
        '"license":"cc-by",'
        '"thumbnail":"https://img/thumb.jpg"'
        '}]}',
        200,
      );
    });
    final provider = OpenverseImageSearchProvider(client: client);

    final result = await provider.search('photo');

    final items = (result as Success<List<ImageSearchResult>>).value;
    expect(items.single.imageUrl, 'https://img/1.jpg');
    expect(items.single.creator, 'Photographer');
    expect(items.single.license, 'cc-by');
    expect(items.single.attribution, 'Photographer · cc-by');
  });

  test('пустой запрос не уходит в сеть', () async {
    var calls = 0;
    final provider = OpenverseImageSearchProvider(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    expect(
      await provider.search('  '),
      isA<Failure<List<ImageSearchResult>>>(),
    );
    expect(calls, 0);
  });
}

class _FakeArticleProvider implements ArticleSearchProvider {
  _FakeArticleProvider(this.items);

  final List<ArticleSearchResult> items;

  @override
  String get name => 'fake';

  @override
  Future<Result<List<ArticleSearchResult>>> search(
    String query, {
    int limit = 10,
  }) async => Result.success(items);
}
