import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:second_brain/app/app.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/app/feature_directions.dart';
import 'package:second_brain/features/notes/presentation/notes_screen.dart';
import 'package:second_brain/features/settings/application/settings_controller.dart';
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

  testWidgets('стартует на дашборде (первая ветка шелла)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // Дашборд — пустой экран первой ветки.
    expect(find.byType(PlaceholderSectionScreen), findsOneWidget);
    // Заголовок первой ветки виден и в AppBar, и в rail.
    expect(find.text('Dashboard'), findsAtLeastNWidgets(2));
  });

  testWidgets('навигация по rail: открывается заметки и настройки', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // Тап по «Notes» в боковом rail.
    final notesLabel = find.text('Notes');
    expect(notesLabel, findsOneWidget);
    await tester.tap(notesLabel);
    await tester.pumpAndSettle();

    expect(find.byType(NotesScreen), findsOneWidget);

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

    await container
        .read(settingsControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    final after = container.read(settingsControllerProvider).value?.themeMode;
    expect(after, ThemeMode.dark);

    // MaterialApp получает выбранный режим темы.
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.themeMode, ThemeMode.dark);
  });

  testWidgets('сброс языка на системный применяется сразу', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    final context = tester.element(find.byType(SecondBrainApp));
    final container = ProviderScope.containerOf(context);
    final controller = container.read(settingsControllerProvider.notifier);

    // Явный русский язык.
    await controller.setLocale(const Locale('ru'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('ru'),
    );

    // Возврат к системному языку должен сбросить локаль (TD-01).
    await controller.setLocale(null);
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);
  });

  testWidgets('низкое окно: rail прокручивается без overflow', (tester) async {
    // 11 пунктов rail не помещаются по высоте: проверяем scrollable.
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Прокрутка вниз открывает нижние разделы.
    await tester.drag(find.byType(NavigationRail), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('узкое окно: скрытая ветка подсвечивает «Ещё»', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // Открываем «Ещё» через нижнюю навигацию.
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    // Переходим в «Settings» — ветку вне нижней панели.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Активной остаётся вкладка «Ещё», а не «Дашборд» (TD-04).
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      navBar.selectedIndex,
      kMobileNavBranches.indexOf(FeatureBranch.more),
    );
  });
}
