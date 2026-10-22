import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/features/notes/presentation/notes_screen.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

/// Widget-тест базового CRUD-сценария заметок поверх in-memory БД.
void main() {
  testWidgets('создание заметки через диалог', (tester) async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => Future.value(db)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Первая заметка');
    await tester.enterText(find.byType(TextField).at(1), 'Тело заметки');
    await tester.enterText(find.byType(TextField).at(2), 'тест, идея');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    // Операция репозитория идёт через реальный event loop SQLite.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    final stored = await tester.runAsync(
      () async => (await DriftNotesRepository(db).list()).unwrap(),
    );
    expect(stored, hasLength(1));

    expect(find.text('Первая заметка'), findsOneWidget);
    expect(find.text('тест'), findsOneWidget);
    expect(find.text('идея'), findsOneWidget);
    expect(find.text('No notes yet'), findsNothing);
  });
}
