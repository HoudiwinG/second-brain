import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../core/secrets/secret_store.dart';
import '../domain/mail_account.dart';
import '../domain/mail_provider_type.dart';

/// OAuth-токены почтового ящика. Хранятся только в SecretStore.
class MailTokens {
  const MailTokens({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String tokenType;

  bool get isExpired => DateTime.now()
      .toUtc()
      .add(const Duration(seconds: 60))
      .isAfter(expiresAt);

  MailTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) => MailTokens(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
    tokenType: tokenType,
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'token_type': tokenType,
  };

  static MailTokens? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final access = raw['access_token'];
    final expires = raw['expires_at'];
    if (access is! String || access.isEmpty || expires is! String) return null;
    final expiresAt = DateTime.tryParse(expires)?.toUtc();
    if (expiresAt == null) return null;
    final refresh = raw['refresh_token'];
    return MailTokens(
      accessToken: access,
      refreshToken: refresh is String && refresh.isNotEmpty ? refresh : null,
      expiresAt: expiresAt,
      tokenType: raw['token_type'] is String
          ? raw['token_type']! as String
          : 'Bearer',
    );
  }
}

/// Чтение/запись токенов по secretRef.
class MailTokenStore {
  const MailTokenStore(this._secrets);

  final SecretStore _secrets;

  Future<Result<MailTokens?>> read(String secretRef) async {
    final raw = await _secrets.read(secretRef);
    return raw.when(
      success: (value) {
        if (value == null || value.isEmpty) return const Result.success(null);
        try {
          return Result.success(
            MailTokens.fromJson(jsonDecode(value) as Object?),
          );
        } on FormatException {
          return const Result.failure(
            DataException('MailOAuth: повреждённые токены в secure storage'),
          );
        }
      },
      failure: Result.failure,
    );
  }

  Future<Result<void>> write(String secretRef, MailTokens tokens) =>
      _secrets.write(secretRef, jsonEncode(tokens.toJson()));

  Future<Result<void>> delete(String secretRef) => _secrets.delete(secretRef);
}

typedef OAuthBrowserLauncher = Future<void> Function(Uri url);

/// Приёмник OAuth callback (loopback). Абстракция нужна для тестов.
abstract interface class OAuthCallbackReceiver {
  Future<void> start({required String state});

  Future<String> waitForCode();

  Future<void> close();
}

/// Loopback HTTP-сервер на зарегистрированном redirect URI.
class LoopbackOAuthCallbackReceiver implements OAuthCallbackReceiver {
  static final Uri redirectUri = Uri.parse(MailProviderType.redirectUri);

  HttpServer? _server;
  Completer<String>? _code;
  String? _state;

  @override
  Future<void> start({required String state}) async {
    _state = state;
    _code = Completer<String>();
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      redirectUri.port,
    );
    _server!.listen((request) async {
      final query = request.uri.queryParameters;
      final response = request.response;
      try {
        if (request.uri.path != redirectUri.path) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          return;
        }
        if (query['state'] != _state) {
          response.statusCode = HttpStatus.badRequest;
          response.write('OAuth state mismatch');
          await response.close();
          return;
        }
        final error = query['error'];
        if (error != null) {
          response.statusCode = HttpStatus.badRequest;
          response.write('OAuth error');
          await response.close();
          if (!_code!.isCompleted) {
            _code!.completeError(
              ValidationException('MailOAuth: провайдер вернул $error'),
            );
          }
          return;
        }
        final code = query['code'];
        if (code == null || code.isEmpty) {
          response.statusCode = HttpStatus.badRequest;
          response.write('OAuth code missing');
          await response.close();
          if (!_code!.isCompleted) {
            _code!.completeError(
              const ValidationException('MailOAuth: код не получен'),
            );
          }
          return;
        }
        response.statusCode = HttpStatus.ok;
        response.headers.contentType = ContentType.html;
        response.write(
          '<html><body>OAuth завершён. Можно закрыть окно и вернуться в '
          'Second Brain.</body></html>',
        );
        await response.close();
        if (!_code!.isCompleted) {
          _code!.complete(code);
        }
      } on Object catch (error, stack) {
        if (!_code!.isCompleted) _code!.completeError(error, stack);
        await response.close();
      }
    });
  }

  @override
  Future<String> waitForCode() {
    final code = _code;
    if (code == null) {
      return Future.error(
        const ValidationException('MailOAuth: callback не запущен'),
      );
    }
    return code.future.timeout(const Duration(minutes: 3));
  }

  @override
  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
    _code = null;
  }
}

/// OAuth 2.0 Authorization Code + PKCE.
class MailOAuthService {
  MailOAuthService({
    required this.tokenStore,
    http.Client? client,
    OAuthBrowserLauncher? browserLauncher,
    OAuthCallbackReceiver Function()? receiverFactory,
    Random? random,
  }) : _client = client ?? http.Client(),
       _browserLauncher = browserLauncher ?? _defaultBrowserLauncher,
       _receiverFactory = receiverFactory ?? LoopbackOAuthCallbackReceiver.new,
       _random = random ?? Random.secure();

  final MailTokenStore tokenStore;
  final http.Client _client;
  final OAuthBrowserLauncher _browserLauncher;
  final OAuthCallbackReceiver Function() _receiverFactory;
  final Random _random;

  Future<Result<MailTokens>> connect(
    MailProviderType provider, {
    required String clientId,
    String? loginHint,
  }) async {
    if (clientId.trim().isEmpty) {
      return const Result.failure(
        ValidationException('MailOAuth: client id не может быть пустым'),
      );
    }
    final state = _randomString(24);
    final verifier = _randomString(48);
    final challenge = _codeChallenge(verifier);
    final receiver = _receiverFactory();
    try {
      await receiver.start(state: state);
      final url = buildAuthorizationUrl(
        provider,
        clientId: clientId,
        state: state,
        codeChallenge: challenge,
        loginHint: loginHint,
      );
      await _browserLauncher(url);
      final code = await receiver.waitForCode();
      return await exchangeCode(
        provider,
        clientId: clientId,
        code: code,
        codeVerifier: verifier,
      );
    } on Object catch (error, stack) {
      return Result.failure(
        error is AppException
            ? error
            : NetworkException(
                'MailOAuth: не удалось завершить OAuth',
                cause: error,
                stackTrace: stack,
              ),
      );
    } finally {
      await receiver.close();
    }
  }

  Uri buildAuthorizationUrl(
    MailProviderType provider, {
    required String clientId,
    required String state,
    required String codeChallenge,
    String? loginHint,
  }) => Uri.parse(provider.authEndpoint).replace(
    queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': MailProviderType.redirectUri,
      'scope': provider.scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
      if (loginHint != null && loginHint.isNotEmpty) 'login_hint': loginHint,
    },
  );

  Future<Result<MailTokens>> exchangeCode(
    MailProviderType provider, {
    required String clientId,
    required String code,
    required String codeVerifier,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(provider.tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'code_verifier': codeVerifier,
          'redirect_uri': MailProviderType.redirectUri,
        },
      );
      return _parseTokenResponse(response, allowRefresh: true);
    } on Object catch (error, stack) {
      return Result.failure(
        NetworkException(
          'MailOAuth: ошибка обмена кода',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<MailTokens>> refresh(
    MailProviderType provider, {
    required String clientId,
    required String refreshToken,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(provider.tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'refresh_token': refreshToken,
        },
      );
      return _parseTokenResponse(response, allowRefresh: false);
    } on Object catch (error, stack) {
      return Result.failure(
        NetworkException(
          'MailOAuth: ошибка обновления токена',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<MailTokens>> ensureToken(MailAccount account) async {
    final stored = await tokenStore.read(account.secretRef);
    if (stored is Failure<MailTokens?>) return Result.failure(stored.error);
    final current = (stored as Success<MailTokens?>).value;
    if (current == null) {
      return const Result.failure(
        ValidationException('MailOAuth: токены ящика не найдены'),
      );
    }
    if (!current.isExpired) return Result.success(current);
    final refreshToken = current.refreshToken;
    if (refreshToken == null) {
      return const Result.failure(
        ValidationException('MailOAuth: нет refresh-токена'),
      );
    }
    final refreshed = await refresh(
      account.provider,
      clientId: account.clientId,
      refreshToken: refreshToken,
    );
    if (refreshed is Failure<MailTokens>) {
      return Result.failure(refreshed.error);
    }
    final tokens = (refreshed as Success<MailTokens>).value;
    final merged = tokens.refreshToken == null
        ? tokens.copyWith(refreshToken: refreshToken)
        : tokens;
    final saved = await tokenStore.write(account.secretRef, merged);
    if (saved is Failure<void>) return Result.failure(saved.error);
    return Result.success(merged);
  }

  Future<Result<void>> storeTokens(String secretRef, MailTokens tokens) =>
      tokenStore.write(secretRef, tokens);

  Future<Result<void>> deleteTokens(String secretRef) =>
      tokenStore.delete(secretRef);

  Result<MailTokens> _parseTokenResponse(
    http.Response response, {
    required bool allowRefresh,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Result.failure(
        NetworkException(
          'MailOAuth: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          retryable: response.statusCode >= 500,
        ),
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        return const Result.failure(
          NetworkException('MailOAuth: некорректный ответ token endpoint'),
        );
      }
      final access = decoded['access_token'];
      if (access is! String || access.isEmpty) {
        return const Result.failure(
          NetworkException('MailOAuth: в ответе нет access_token'),
        );
      }
      final expiresIn = decoded['expires_in'];
      final seconds = expiresIn is num ? expiresIn.toInt() : 3600;
      final refresh = decoded['refresh_token'];
      return Result.success(
        MailTokens(
          accessToken: access,
          refreshToken: allowRefresh && refresh is String && refresh.isNotEmpty
              ? refresh
              : null,
          expiresAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
          tokenType: decoded['token_type'] is String
              ? decoded['token_type']! as String
              : 'Bearer',
        ),
      );
    } on FormatException {
      return const Result.failure(
        NetworkException('MailOAuth: некорректный JSON token endpoint'),
      );
    }
  }

  String _randomString(int bytes) => base64Url
      .encode(List<int>.generate(bytes, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  static String _codeChallenge(String verifier) => base64Url
      .encode(sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');

  static Future<void> _defaultBrowserLauncher(Uri url) async {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', url.toString()]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url.toString()]);
    } else {
      await Process.start('xdg-open', [url.toString()]);
    }
  }
}
