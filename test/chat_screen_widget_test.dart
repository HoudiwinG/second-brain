import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/features/chat/presentation/chat_screen.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

void main() {
  testWidgets('чат без провайдера показывает настройки', (tester) async {
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
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Chat'), findsOneWidget);
    expect(
      find.text('Add an LLM provider and API key in Settings first.'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
  });
}
