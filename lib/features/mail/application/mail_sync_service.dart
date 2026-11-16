import '../../../core/result/result.dart';
import '../data/mail_provider.dart';
import '../domain/mail_account.dart';
import '../domain/mail_message.dart';
import '../domain/mail_repository.dart';
import 'mail_oauth.dart';

/// Синхронизация писем: OAuth-токен → официальный API → локальный кэш.
class MailSyncService {
  MailSyncService({required this.repository, required this.oauth});

  final MailRepository repository;
  final MailOAuthService oauth;

  Future<Result<int>> sync(
    MailAccount account, {
    String? query,
    int limit = 20,
  }) async {
    final tokenResult = await oauth.ensureToken(account);
    if (tokenResult is Failure<MailTokens>) {
      return Result.failure(tokenResult.error);
    }
    final tokens = (tokenResult as Success<MailTokens>).value;
    final provider = createMailProvider(account);
    final fetched = await provider.fetchMessages(
      account: account,
      tokens: tokens,
      query: query,
      limit: limit,
    );
    if (fetched is Failure<List<MailMessageDraft>>) {
      return Result.failure(fetched.error);
    }
    final messages = (fetched as Success<List<MailMessageDraft>>).value;
    return repository.upsertMessages(account.id, messages);
  }
}
