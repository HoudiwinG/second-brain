import '../../../core/result/result.dart';
import 'mail_account.dart';
import 'mail_message.dart';

/// Локальные аккаунты и кэш писем.
abstract interface class MailRepository {
  Future<Result<List<MailAccount>>> listAccounts();

  Future<Result<MailAccount?>> getAccount(int id);

  Future<Result<MailAccount>> createAccount(MailAccountDraft draft);

  Future<Result<MailAccount>> updateAccount(
    int id, {
    String? displayName,
    bool? isPrivateForLlm,
  });

  Future<Result<void>> deleteAccount(int id);

  Future<Result<List<MailMessage>>> listMessages({
    int? accountId,
    String? query,
    bool forLlm = false,
    int limit = 50,
  });

  Future<Result<MailMessage?>> getMessage(int id);

  /// Upsert писем по (accountId, remoteId); возвращает количество записей.
  Future<Result<int>> upsertMessages(
    int accountId,
    List<MailMessageDraft> messages,
  );

  Future<Result<void>> deleteMessage(int id);
}
