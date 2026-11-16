import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/mail_repository.dart';
import 'package:second_brain/features/integrations/presentation/integrations_screen.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;

  setUp(() {
    db = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
  });

  testWidgets('пустое состояние почты', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: _app(const IntegrationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Integrations'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('No mailboxes connected'), findsOneWidget);
  });

  testWidgets('показывает подключённый ящик', (tester) async {
    await DriftMailRepository(db, secrets).createAccount(
      const MailAccountDraft(
        provider: MailProviderType.gmail,
        email: 'user@example.com',
        displayName: 'Work',
        clientId: 'client',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: _app(const IntegrationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
  });
}
