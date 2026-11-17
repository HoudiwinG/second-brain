import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/ideas_repository.dart';
import 'package:second_brain/features/ideas/data/article_search_providers.dart';
import 'package:second_brain/features/ideas/data/image_search_providers.dart';
import 'package:second_brain/features/ideas/domain/idea_search.dart';
import 'package:second_brain/features/ideas/presentation/ideas_screen.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

class _ArticleProvider implements ArticleSearchProvider {
  @override
  String get name => 'fake';

  @override
  Future<Result<List<ArticleSearchResult>>> search(
    String query, {
    int limit = 10,
  }) async => const Result.success([
    ArticleSearchResult(
      title: 'Found article',
      url: 'https://example.com/article',
      source: 'Example',
      summary: 'Useful summary',
    ),
  ]);
}

class _ImageProvider implements ImageSearchProvider {
  @override
  String get name => 'fake';

  @override
  Future<Result<List<ImageSearchResult>>> search(
    String query, {
    int limit = 12,
  }) async => const Result.success([]);
}

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;

  setUp(() {
    db = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
  });

  testWidgets('поиск статьи сохраняет идею', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
          articleSearchServiceProvider.overrideWithValue(
            ArticleSearchService([_ArticleProvider()]),
          ),
          imageSearchServiceProvider.overrideWithValue(
            ImageSearchService(_ImageProvider()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const IdeasScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.travel_explore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Search articles and images'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'topic');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Found article'), findsOneWidget);
    await tester.tap(find.text('To ideas'));
    await tester.pumpAndSettle();

    final ideas = (await DriftIdeasRepository(db).list()).unwrap();
    expect(ideas, hasLength(1));
    expect(ideas.single.text, contains('Found article'));
    expect(ideas.single.source, 'https://example.com/article');
  });
}
