import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/repositories/llm_config_repository.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';
import 'package:second_brain/features/llm/presentation/llm_settings_section.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('секция показывает сохранённого провайдера', (tester) async {
    final db = InMemoryDbFactory.open();
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
    await DriftLlmConfigRepository(db, secrets).create(
      const LlmConfigDraft(
        type: LlmProviderType.openai,
        displayName: 'My OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'secret',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: _app(const LlmSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LLM providers'), findsOneWidget);
    expect(find.text('My OpenAI'), findsOneWidget);
    expect(find.textContaining('gpt-4o-mini'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.textContaining('Key saved'), findsOneWidget);
  });

  testWidgets('диалог сохраняет нового провайдера', (tester) async {
    final db = InMemoryDbFactory.open();
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: _app(const LlmSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add provider').first);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));
    await tester.enterText(fields.at(0), 'Local model');
    await tester.enterText(fields.at(1), 'http://localhost:11434/v1');
    await tester.enterText(fields.at(2), 'llama3.1');
    await tester.enterText(fields.at(3), 'nomic-embed-text');
    await tester.enterText(fields.at(4), 'optional-key');
    await tester.enterText(fields.at(5), '2048');

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuration saved'), findsOneWidget);
    expect(find.text('Local model'), findsOneWidget);
    final stored = await tester.runAsync(
      () async => (await DriftLlmConfigRepository(db, secrets).list()).unwrap(),
    );
    expect(stored, isNotNull);
    expect(stored, hasLength(1));
    final items = stored!;
    expect(items.single.type, LlmProviderType.openai);
    expect(items.single.maxTokens, 2048);
    expect(items.single.model, 'llama3.1');
    expect(items.single.embeddingModel, 'nomic-embed-text');
    expect(items.single.hasApiKey, isTrue);
  });

  testWidgets('невалидный maxTokens не закрывает диалог и не пишет в БД', (
    tester,
  ) async {
    final db = InMemoryDbFactory.open();
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: _app(const LlmSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add provider').first);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(5), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter a number from 1 to 32768'), findsOneWidget);
    expect(await db.select(db.llmProviderConfigs).get(), isEmpty);
  });

  testWidgets('ключ можно удалить, а невалидный ввод не теряется', (
    tester,
  ) async {
    final db = InMemoryDbFactory.open();
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
    await DriftLlmConfigRepository(db, secrets).create(
      const LlmConfigDraft(
        type: LlmProviderType.openai,
        displayName: 'Editable',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'secret',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: _app(const LlmSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Delete saved key'), findsOneWidget);

    final nameField = find.byType(TextField).at(0);
    await tester.enterText(nameField, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      isEmpty,
    );

    await tester.enterText(find.byType(TextField).at(0), 'Editable');
    final deleteKey = find.text('Delete saved key');
    await tester.ensureVisible(deleteKey);
    await tester.pumpAndSettle();
    await tester.tap(deleteKey);
    await tester.pump();
    expect(find.textContaining('will be deleted'), findsOneWidget);
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(secrets.debugValues, isEmpty);
    expect(find.textContaining('No key'), findsOneWidget);
  });
}
