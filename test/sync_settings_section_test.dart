import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/sync/sync_service.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';
import 'package:second_brain/features/sync/data/sync_profile_repository.dart';
import 'package:second_brain/features/sync/domain/sync_profile.dart';
import 'package:second_brain/features/sync/presentation/sync_settings_section.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

void main() {
  testWidgets('sync UI: idle enabled, busy disabled, undo after pull', (
    tester,
  ) async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final profiles = SyncProfileRepository(SettingsRepository(db));
    await profiles.create('Local');
    final service = _ControllableSyncService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          syncServiceProvider.overrideWith((ref) async => service),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SyncSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final push = find.ancestor(
      of: find.byIcon(Icons.upload_outlined),
      matching: find.byType(IconButton),
    );
    final pull = find.ancestor(
      of: find.byIcon(Icons.download_outlined),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(push).onPressed, isNotNull);
    expect(tester.widget<IconButton>(pull).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Получить'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final busyPull = find.ancestor(
      of: find.byIcon(Icons.download_outlined),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(busyPull).onPressed, isNull);

    service.pullCompleter.complete(const Result.success(null));
    await tester.pumpAndSettle();

    expect(find.text('Отменить последний pull'), findsOneWidget);
  });

  testWidgets('sync UI: push completes and re-enables buttons', (tester) async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final profiles = SyncProfileRepository(SettingsRepository(db));
    await profiles.create('Local');
    final service = _ControllableSyncService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          syncServiceProvider.overrideWith((ref) async => service),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SyncSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.upload_outlined));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.pushCompleter.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.upload_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _ControllableSyncService implements SyncService {
  final pushCompleter = Completer<Result<void>>();
  final pullCompleter = Completer<Result<void>>();

  @override
  Future<Result<void>> push(SyncProfile profile) => pushCompleter.future;

  @override
  Future<Result<void>> pull(SyncProfile profile) => pullCompleter.future;

  @override
  Future<Result<void>> undoLastPull() async => const Result.success(null);

  @override
  Stream<SyncStatus> get status => const Stream<SyncStatus>.empty();
}
