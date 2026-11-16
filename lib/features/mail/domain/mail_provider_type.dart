/// Почтовый провайдер. OAuth-эндпоинты публичны; client id вводит пользователь.
enum MailProviderType {
  gmail(
    dbValue: 'gmail',
    label: 'Gmail',
    authEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    apiBaseUrl: 'https://gmail.googleapis.com/gmail/v1',
    scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'openid',
      'email',
    ],
  ),
  yandex(
    dbValue: 'yandex',
    label: 'Yandex Mail',
    authEndpoint: 'https://oauth.yandex.ru/authorize',
    tokenEndpoint: 'https://oauth.yandex.ru/token',
    apiBaseUrl: 'https://cloud-api.yandex.net/v1/mail',
    scopes: ['mail:messages.read'],
    authScheme: 'OAuth',
  ),
  mailru(
    dbValue: 'mailru',
    label: 'Mail.ru',
    authEndpoint: 'https://oauth.mail.ru/login',
    tokenEndpoint: 'https://oauth.mail.ru/token',
    apiBaseUrl: 'https://api.mail.ru',
    scopes: ['mail:read'],
    available: false,
  );

  const MailProviderType({
    required this.dbValue,
    required this.label,
    required this.authEndpoint,
    required this.tokenEndpoint,
    required this.apiBaseUrl,
    required this.scopes,
    this.authScheme = 'Bearer',
    this.available = true,
  });

  final String dbValue;
  final String label;
  final String authEndpoint;
  final String tokenEndpoint;
  final String apiBaseUrl;
  final List<String> scopes;

  /// Схема Authorization для API провайдера.
  final String authScheme;

  /// Провайдер можно подключить в текущей реализации.
  ///
  /// Mail.ru официально не предоставляет REST API чтения писем, поэтому
  /// подключение отключено, пока не появится официальный контракт.
  final bool available;

  /// Локальный loopback callback; должен быть зарегистрирован в OAuth-приложении.
  static const String redirectUri = 'http://127.0.0.1:53682/oauth/callback';

  static MailProviderType fromDb(String raw) => MailProviderType.values
      .firstWhere((value) => value.dbValue == raw, orElse: () => gmail);
}
