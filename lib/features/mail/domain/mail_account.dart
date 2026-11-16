import 'mail_provider_type.dart';

/// Подключённый почтовый ящик.
class MailAccount {
  const MailAccount({
    required this.id,
    required this.provider,
    required this.email,
    required this.displayName,
    required this.clientId,
    required this.secretRef,
    required this.isPrivateForLlm,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final MailProviderType provider;
  final String email;
  final String displayName;

  /// Публичный OAuth client id; токены лежат в SecretStore по [secretRef].
  final String clientId;
  final String secretRef;

  /// true — письма этого ящика не отправляются в LLM.
  final bool isPrivateForLlm;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Данные подключения ящика.
class MailAccountDraft {
  const MailAccountDraft({
    required this.provider,
    required this.email,
    this.displayName = '',
    required this.clientId,
    this.isPrivateForLlm = false,
  });

  final MailProviderType provider;
  final String email;
  final String displayName;
  final String clientId;
  final bool isPrivateForLlm;
}
