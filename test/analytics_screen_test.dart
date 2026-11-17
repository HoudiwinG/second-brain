import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/features/analytics/presentation/analytics_screen.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

void main() {
  testWidgets('аналитика показывает нулевые метрики', (tester) async {
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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Open tasks'), findsOneWidget);
    expect(find.text('Top expenses'), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);
  });
}
