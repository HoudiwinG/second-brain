import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:second_brain/app/app.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/app/settings_controller.dart';
import 'package:second_brain/app/widgets/placeholder_section_screen.dart';
import 'package:second_brain/data/db/app_database.dart';

import 'helpers/in_memory_db.dart';

/// Widget-тест роутинга: навигация по веткам шелла приложения поверх
/// in-memory БД (без secure storage и системных плагинов).
///
/// В тестовой среде системная локаль = en-US, поэтому ожидания — EN-строки.
void main() {
  late AppDatabase db;

  setUp(() {
    db = InMemoryDbFactory.open();
  });

  tearDown(() {
    db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => Future.value(db)),
        ],
        child: const SecondBrainApp(),
      ),
    );
    // Несколько кадров: даём AsyncNotifier'у настроек долететь до AsyncData.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('стартует на дашборде (первая веткао шелла)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // Дашборд — пустой экран первой ветки.
    expect(find.byType(PlaceholderSectionScreen), findsOneWidget);
    // Заголовок первой ветки виден и в AppBar, и в rail.
    expect(find.text('Dashboard'), findsAtLeastNWidgets(2));
  });

  testWidgets('навигация по rail: открывается заметки и настройки', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // Тап по «Notes» в боковом rail.
    final notesLabel = find.text('Notes');
    expect(notesLabel, findsOneWidget);
    await tester.tap(notesLabel);
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderSectionScreen), findsOneWidget);

    // Тап по «Settings» в боковом rail.
    final settingsLabel = find.text('Settings');
    expect(settingsLabel, findsOneWidget);
    await tester.tap(settingsLabel);
    await tester.pumpAndSettle();

    // В настройках видны локализованные переключатели.
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('переключение темы применяется к MaterialApp', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    final context = tester.element(find.byType(SecondBrainApp));
    final container = ProviderScope.containerOf(context);

    final before = container.read(settingsControllerProvider).value?.themeMode;
    expect(before, ThemeMode.system);

    await container.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    final after = container.read(settingsControllerProvider).value?.themeMode;
    expect(after, ThemeMode.dark);

    // MaterialApp получает выбранный режим темы.
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.themeMode, ThemeMode.dark);
  });
}
