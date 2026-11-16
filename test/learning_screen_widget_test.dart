import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/learning_repository.dart';
import 'package:second_brain/features/learning/domain/learning_track.dart';
import 'package:second_brain/features/learning/presentation/learning_screen.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late AppDatabase db;
  late DriftLearningRepository repository;

  setUp(() {
    db = InMemoryDbFactory.open();
    addTearDown(db.close);
    repository = DriftLearningRepository(db);
  });

  testWidgets('пустое состояние обучения', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        child: _app(const LearningScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('No learning tracks yet'), findsOneWidget);
  });

  testWidgets('показывает трек и открывает детали', (tester) async {
    final track = (await repository.createTrack(
      const LearningTrackDraft(
        title: 'Dart',
        goal: 'Писать приложения',
        steps: [LearningStep(id: 's1', title: 'Основы')],
      ),
    )).unwrap();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        child: _app(const LearningScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('Progress: 0/1'), findsOneWidget);

    await tester.tap(find.text('Dart'));
    await tester.pumpAndSettle();

    expect(find.text('Roadmap'), findsOneWidget);
    expect(find.text('Основы'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('No sessions yet'), findsOneWidget);
    expect(track.id, greaterThan(0));
  });
}
