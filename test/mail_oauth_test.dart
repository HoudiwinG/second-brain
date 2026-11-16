import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/features/mail/application/mail_oauth.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';

void main() {
  late InMemorySecretStore secrets;
  late MailTokenStore tokenStore;

  setUp(() {
    secrets = InMemorySecretStore();
    addTearDown(secrets.clear);
    tokenStore = MailTokenStore(secrets);
  });

  test('строит authorization URL с PKCE и scope', () {
    final service = MailOAuthService(tokenStore: tokenStore);
    final url = service.buildAuthorizationUrl(
      MailProviderType.gmail,
      clientId: 'client',
      state: 'state',
      codeChallenge: 'challenge',
      loginHint: 'user@example.com',
    );

    expect(url.host, 'accounts.google.com');
    expect(url.queryParameters['client_id'], 'client');
    expect(url.queryParameters['code_challenge'], 'challenge');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    expect(url.queryParameters['state'], 'state');
    expect(url.queryParameters['redirect_uri'], MailProviderType.redirectUri);
    expect(url.queryParameters['scope'], contains('gmail.readonly'));
  });

  test('обменивает code на токены и сохраняет их', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'oauth2.googleapis.com');
      expect(request.body, contains('code_verifier=verifier'));
      return http.Response(
        jsonEncode({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        200,
      );
    });
    final service = MailOAuthService(tokenStore: tokenStore, client: client);

    final result = await service.exchangeCode(
      MailProviderType.gmail,
      clientId: 'client',
      code: 'code',
      codeVerifier: 'verifier',
    );

    final tokens = (result as Success<MailTokens>).value;
    expect(tokens.accessToken, 'access');
    expect(tokens.refreshToken, 'refresh');
    expect(tokens.isExpired, isFalse);
    (await service.storeTokens('secret-ref', tokens)).unwrap();
    final loaded = (await tokenStore.read('secret-ref')).unwrap()!;
    expect(loaded.accessToken, 'access');
  });

  test('refresh сохраняет старый refresh-token', () async {
    final client = MockClient((request) async {
      expect(request.body, contains('grant_type=refresh_token'));
      return http.Response(
        jsonEncode({'access_token': 'new-access', 'expires_in': 3600}),
        200,
      );
    });
    final service = MailOAuthService(tokenStore: tokenStore, client: client);
    final account = MailAccount(
      id: 1,
      provider: MailProviderType.gmail,
      email: 'user@example.com',
      displayName: '',
      clientId: 'client',
      secretRef: 'secret-ref',
      isPrivateForLlm: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    (await tokenStore.write(
      account.secretRef,
      MailTokens(
        accessToken: 'old',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2020, 1, 1),
      ),
    )).unwrap();

    final result = await service.ensureToken(account);

    final tokens = (result as Success<MailTokens>).value;
    expect(tokens.accessToken, 'new-access');
    expect(tokens.refreshToken, 'refresh');
    expect(
      (await tokenStore.read(account.secretRef)).unwrap()!.accessToken,
      'new-access',
    );
  });

  test('HTTP-ошибка token endpoint не логирует тело', () async {
    final client = MockClient(
      (request) async => http.Response('provider body', 500),
    );
    final service = MailOAuthService(tokenStore: tokenStore, client: client);

    final result = await service.exchangeCode(
      MailProviderType.gmail,
      clientId: 'client',
      code: 'code',
      codeVerifier: 'verifier',
    );

    expect(result, isA<Failure<MailTokens>>());
    expect(result.toString(), isNot(contains('provider body')));
  });
}
