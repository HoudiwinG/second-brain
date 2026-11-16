import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/error/app_exception.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/features/mail/application/mail_oauth.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';

class _FakeReceiver implements OAuthCallbackReceiver {
  String? state;
  var closed = false;

  @override
  Future<void> start({required String state}) async {
    this.state = state;
  }

  @override
  Future<String> waitForCode() async => 'code';

  @override
  Future<void> close() async {
    closed = true;
  }
}

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

  test('connect: state, PKCE и полный URL без обрезки', () async {
    final receiver = _FakeReceiver();
    String? launched;
    String? verifier;
    final client = MockClient((request) async {
      final body = Uri.splitQueryString(request.body);
      verifier = body['code_verifier'];
      expect(body['client_secret'], 'secret');
      return http.Response(
        jsonEncode({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 3600,
        }),
        200,
      );
    });
    final service = MailOAuthService(
      tokenStore: tokenStore,
      client: client,
      browserLauncher: (url) async => launched = url.toString(),
      receiverFactory: () => receiver,
    );

    final result = await service.connect(
      MailProviderType.gmail,
      clientId: 'client',
      clientSecret: 'secret',
    );

    expect(result, isA<Success<MailTokens>>());
    expect(receiver.closed, isTrue);
    expect(launched, isNotNull);
    final url = Uri.parse(launched!);
    expect(url.queryParameters['state'], receiver.state);
    expect(url.queryParameters['state'], isNotEmpty);
    expect(
      url.queryParameters['code_challenge'],
      MailOAuthService.pkceChallenge(verifier!),
    );
    // Полный URL содержит несколько query-параметров, то есть '&' не потерян.
    expect(launched, contains('&scope='));
    expect(launched, contains('&code_challenge_method=S256'));
  });

  test('Windows launcher передаёт URL одним аргументом без cmd', () {
    final url = Uri.parse(
      'https://accounts.google.com/o/oauth2/v2/auth?a=1&b=2&c=3',
    );
    final command = MailOAuthService.browserCommand(url, isWindows: true);
    expect(command.$1, 'rundll32');
    expect(command.$2, hasLength(2));
    expect(command.$2.last, url.toString());
    expect(command.$2.last, contains('&b=2&c=3'));
  });

  test('недоступный Mail.ru не запускает OAuth', () async {
    final service = MailOAuthService(
      tokenStore: tokenStore,
      browserLauncher: (_) async => fail('browser must not launch'),
    );
    final result = await service.connect(
      MailProviderType.mailru,
      clientId: 'client',
    );
    expect(result, isA<Failure<MailTokens>>());
  });

  test('token endpoint повторяется после 5xx', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) return http.Response('temporary', 503);
      return http.Response(
        jsonEncode({'access_token': 'access', 'expires_in': 3600}),
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
    expect((result as Success<MailTokens>).value.accessToken, 'access');
    expect(calls, 2);
  });

  test('invalid refresh удаляет битые токены', () async {
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
        refreshToken: 'revoked',
        expiresAt: DateTime.utc(2020, 1, 1),
      ),
    )).unwrap();
    final client = MockClient(
      (request) async =>
          http.Response(jsonEncode({'error': 'invalid_grant'}), 400),
    );
    final service = MailOAuthService(tokenStore: tokenStore, client: client);

    final result = await service.ensureToken(account);

    expect(result, isA<Failure<MailTokens>>());
    expect((await tokenStore.read(account.secretRef)).unwrap(), isNull);
  });

  test('loopback отклоняет callback с чужим state', () async {
    final receiver = LoopbackOAuthCallbackReceiver();
    addTearDown(receiver.close);
    await receiver.start(state: 'expected');
    final codeFuture = receiver.waitForCode();
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(
      LoopbackOAuthCallbackReceiver.redirectUri.replace(
        queryParameters: {'state': 'wrong', 'code': 'x'},
      ),
    );
    final response = await request.close();
    await response.drain<void>();

    await expectLater(codeFuture, throwsA(isA<ValidationException>()));
  });
}
