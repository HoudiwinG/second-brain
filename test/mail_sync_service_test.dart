import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/error/app_exception.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/mail_repository.dart';
import 'package:second_brain/features/mail/application/mail_oauth.dart';
import 'package:second_brain/features/mail/application/mail_sync_service.dart';
import 'package:second_brain/features/mail/data/mail_provider.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';

import 'helpers/in_memory_db.dart';

class _FakeProvider implements MailProvider {
  var calls = 0;

  @override
  Future<Result<List<MailMessageDraft>>> fetchMessages({
    required MailAccount account,
    required MailTokens tokens,
    String? query,
    int limit = 20,
  }) async {
    calls++;
    if (calls == 1) {
      return const Result.failure(
        NetworkException('unauthorized', statusCode: 401),
      );
    }
    expect(tokens.accessToken, 'new-access');
    return Result.success([
      MailMessageDraft(
        remoteId: 'm1',
        fromAddress: 'sender@example.com',
        subject: 'Тема',
        snippet: 'Кратко',
        body: 'Тело',
        receivedAt: DateTime.utc(2026, 11, 1),
      ),
    ]);
  }
}

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late DriftMailRepository repo;
  late MailTokenStore tokenStore;

  setUp(() {
    db = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
    repo = DriftMailRepository(db, secrets);
    tokenStore = MailTokenStore(secrets);
  });

  test('401 от API обновляет токен и повторяет синхронизацию', () async {
    final account = (await repo.createAccount(
      const MailAccountDraft(
        provider: MailProviderType.gmail,
        email: 'user@example.com',
        clientId: 'client',
      ),
    )).unwrap();
    (await tokenStore.write(
      account.secretRef,
      MailTokens(
        accessToken: 'old-access',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2030, 1, 1),
      ),
    )).unwrap();
    final client = MockClient((request) async {
      expect(request.body, contains('grant_type=refresh_token'));
      return http.Response(
        jsonEncode({
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'expires_in': 3600,
        }),
        200,
      );
    });
    final oauth = MailOAuthService(tokenStore: tokenStore, client: client);
    final provider = _FakeProvider();
    final service = MailSyncService(
      repository: repo,
      oauth: oauth,
      providerFactory: (_) => provider,
    );

    final count = (await service.sync(account)).unwrap();

    expect(count, 1);
    expect(provider.calls, 2);
    final stored = (await tokenStore.read(account.secretRef)).unwrap()!;
    expect(stored.accessToken, 'new-access');
    expect(stored.refreshToken, 'new-refresh');
    final messages = (await repo.listMessages()).unwrap();
    expect(messages.single.remoteId, 'm1');
  });
}
