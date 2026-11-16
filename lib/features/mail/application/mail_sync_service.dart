import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../data/mail_provider.dart';
import '../domain/mail_account.dart';
import '../domain/mail_message.dart';
import '../domain/mail_repository.dart';
import 'mail_oauth.dart';

/// Синхронизация писем: OAuth-токен → официальный API → локальный кэш.
class MailSyncService {
  MailSyncService({
    required this.repository,
    required this.oauth,
    MailProvider Function(MailAccount account)? providerFactory,
  }) : _providerFactory = providerFactory ?? createMailProvider;

  final MailRepository repository;
  final MailOAuthService oauth;
  final MailProvider Function(MailAccount account) _providerFactory;

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
    final provider = _providerFactory(account);
    var fetched = await provider.fetchMessages(
      account: account,
      tokens: tokens,
      query: query,
      limit: limit,
    );
    if (fetched is Failure<List<MailMessageDraft>> &&
        fetched.error is NetworkException &&
        (fetched.error as NetworkException).statusCode == 401) {
      // Access token отозван/просрочен: один раз обновляем и повторяем.
      final refreshed = await oauth.forceRefresh(account);
      if (refreshed is Failure<MailTokens>) {
        return Result.failure(refreshed.error);
      }
      fetched = await provider.fetchMessages(
        account: account,
        tokens: (refreshed as Success<MailTokens>).value,
        query: query,
        limit: limit,
      );
    }
    if (fetched is Failure<List<MailMessageDraft>>) {
      return Result.failure(fetched.error);
    }
    final messages = (fetched as Success<List<MailMessageDraft>>).value;
    return repository.upsertMessages(account.id, messages);
  }
}
