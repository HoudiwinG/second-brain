import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/repositories/chat_repository.dart';
import 'package:second_brain/features/chat/domain/chat_message.dart';
import 'package:second_brain/features/chat/domain/chat_thread.dart';
import 'package:second_brain/features/chat/presentation/chat_screen.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

import 'helpers/in_memory_db.dart';

void main() {
  testWidgets('чат без провайдера показывает историю и ведёт в настройки', (
    tester,
  ) async {
    final db = InMemoryDbFactory.open();
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);

    final chats = DriftChatRepository(db);
    final thread = (await chats.createThread(
      const ChatThreadDraft(
        title: 'Offline thread',
        providerConfigId: null,
        model: 'offline-model',
      ),
    )).unwrap();
    await chats.appendMessage(
      ChatMessageDraft(
        threadId: thread.id,
        role: LlmRole.user,
        content: 'Saved question',
      ),
    );
    await chats.appendMessage(
      ChatMessageDraft(
        threadId: thread.id,
        role: LlmRole.assistant,
        content: 'Saved answer',
      ),
    );

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('Settings destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          secretStoreProvider.overrideWithValue(secrets),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved question'), findsOneWidget);
    expect(find.text('Saved answer'), findsOneWidget);
    expect(find.textContaining('Add an LLM provider'), findsWidgets);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings destination'), findsOneWidget);
  });
}
