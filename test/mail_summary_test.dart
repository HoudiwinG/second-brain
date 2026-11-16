import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/llm_config_repository.dart';
import 'package:second_brain/features/llm/data/llm_provider_factory.dart';
import 'package:second_brain/features/llm/domain/llm_provider_config.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';
import 'package:second_brain/features/mail/application/mail_summary_service.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';

import 'helpers/in_memory_db.dart';

String _sse(String text) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': text},
        },
      ],
    })}\n\n'
    'data: [DONE]\n\n';

MailMessage _message({bool private = false}) => MailMessage(
  id: 1,
  accountId: 1,
  remoteId: 'm1',
  threadId: null,
  fromAddress: 'sender@example.com',
  subject: 'Тема',
  snippet: 'Кратко',
  body: 'Тело письма',
  receivedAt: DateTime.utc(2026, 11, 1),
  isPrivateForLlm: private,
  createdAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late LlmProviderConfig config;

  setUp(() async {
    db = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
    config = (await DriftLlmConfigRepository(db, secrets).create(
      const LlmConfigDraft(
        type: LlmProviderType.openai,
        displayName: 'Test',
        baseUrl: 'https://api.test/v1',
        model: 'test-model',
        maxTokens: 512,
        apiKey: 'key',
      ),
    )).unwrap();
  });

  MailSummaryService service(http.Client client) => MailSummaryService(
    configs: [config],
    configRepo: DriftLlmConfigRepository(db, secrets),
    factory: LlmProviderFactory(client: client, retryDelay: (_) async {}),
  );

  test('суммаризирует письмо через LLM', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode(_sse('Резюме письма'))),
        200,
        request: request,
      );
    });

    final result = await service(client).summarizeMessage(_message());

    expect((result as Success<String>).value, 'Резюме письма');
  });

  test('приватное письмо не отправляется в LLM', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 500);
    });

    final result = await service(client)
        .summarizeMessage(_message(private: true));

    expect(result, isA<Failure<String>>());
    expect(called, isFalse);
  });
}
