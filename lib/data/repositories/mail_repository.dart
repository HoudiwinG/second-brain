import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../../core/secrets/secret_store.dart';
import '../../features/mail/domain/mail_account.dart';
import '../../features/mail/domain/mail_message.dart';
import '../../features/mail/domain/mail_provider_type.dart';
import '../../features/mail/domain/mail_repository.dart';
import '../db/app_database.dart' as db;
import 'repository_guard.dart';

/// Drift-реализация почтовых аккаунтов и кэша писем.
class DriftMailRepository implements MailRepository {
  DriftMailRepository(this._db, this._secrets, {Random? random})
    : _random = random ?? Random.secure();

  final db.AppDatabase _db;
  final SecretStore _secrets;
  final Random _random;

  @override
  Future<Result<List<MailAccount>>> listAccounts() {
    return RepositoryGuard.guard('MailRepository.listAccounts', () async {
      final rows = await (_db.select(
        _db.mailAccounts,
      )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
      return [for (final row in rows) _toAccount(row)];
    });
  }

  @override
  Future<Result<MailAccount?>> getAccount(int id) {
    return RepositoryGuard.guard('MailRepository.getAccount', () async {
      final row = await (_db.select(
        _db.mailAccounts,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _toAccount(row);
    });
  }

  @override
  Future<Result<MailAccount>> createAccount(MailAccountDraft draft) {
    return RepositoryGuard.guard('MailRepository.createAccount', () async {
      final email = draft.email.trim().toLowerCase();
      if (!email.contains('@') || email.length > 320) {
        throw const ValidationException('MailRepository: некорректный email');
      }
      final clientId = draft.clientId.trim();
      if (clientId.isEmpty) {
        throw const ValidationException(
          'MailRepository: OAuth client id не может быть пустым',
        );
      }
      final now = DateTime.now().toUtc();
      final secretRef = _newSecretRef();
      final id = await _db
          .into(_db.mailAccounts)
          .insert(
            db.MailAccountsCompanion.insert(
              providerType: draft.provider.dbValue,
              email: email,
              displayName: Value(draft.displayName.trim()),
              clientId: Value(clientId),
              secretRef: secretRef,
              isPrivateForLlm: Value(draft.isPrivateForLlm),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final row = await (_db.select(
        _db.mailAccounts,
      )..where((t) => t.id.equals(id))).getSingle();
      return _toAccount(row);
    });
  }

  @override
  Future<Result<MailAccount>> updateAccount(
    int id, {
    String? displayName,
    bool? isPrivateForLlm,
  }) {
    return RepositoryGuard.guard('MailRepository.updateAccount', () async {
      final current = await _findAccount(id);
      if (current == null) {
        throw ValidationException('MailRepository: аккаунт $id не найден');
      }
      await (_db.update(_db.mailAccounts)..where((t) => t.id.equals(id))).write(
        db.MailAccountsCompanion(
          displayName: displayName == null
              ? const Value.absent()
              : Value(displayName.trim()),
          isPrivateForLlm: isPrivateForLlm == null
              ? const Value.absent()
              : Value(isPrivateForLlm),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      final row = await _findAccount(id);
      return _toAccount(row!);
    });
  }

  @override
  Future<Result<void>> deleteAccount(int id) {
    return RepositoryGuard.guard('MailRepository.deleteAccount', () async {
      final current = await _findAccount(id);
      if (current == null) return;
      await (_db.delete(_db.mailAccounts)..where((t) => t.id.equals(id))).go();
      final deleted = await _secrets.delete(current.secretRef);
      deleted.when(
        success: (_) {},
        failure: (error) => AppLogger.w(
          'MailRepository: не удалось удалить OAuth-токены аккаунта $id',
          error.message,
        ),
      );
    });
  }

  @override
  Future<Result<List<MailMessage>>> listMessages({
    int? accountId,
    String? query,
    bool forLlm = false,
    int limit = 50,
  }) {
    return RepositoryGuard.guard('MailRepository.listMessages', () async {
      final q = _db.select(_db.mailMessages);
      if (accountId != null) {
        q.where((m) => m.accountId.equals(accountId));
      }
      if (forLlm) {
        q.where((m) => m.isPrivateForLlm.equals(false));
      }
      final text = query?.trim();
      if (text != null && text.isNotEmpty) {
        final like = '%${text.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
        q.where(
          (m) =>
              m.subject.like(like) |
              m.fromAddress.like(like) |
              m.snippet.like(like) |
              m.body.like(like),
        );
      }
      q.orderBy([
        (m) => OrderingTerm.desc(m.receivedAt),
        (m) => OrderingTerm.desc(m.id),
      ]);
      q.limit(limit.clamp(1, 200));
      final rows = await q.get();
      return [for (final row in rows) _toMessage(row)];
    });
  }

  @override
  Future<Result<MailMessage?>> getMessage(int id) {
    return RepositoryGuard.guard('MailRepository.getMessage', () async {
      final row = await (_db.select(
        _db.mailMessages,
      )..where((m) => m.id.equals(id))).getSingleOrNull();
      return row == null ? null : _toMessage(row);
    });
  }

  @override
  Future<Result<int>> upsertMessages(
    int accountId,
    List<MailMessageDraft> messages,
  ) {
    return RepositoryGuard.guard('MailRepository.upsertMessages', () async {
      final account = await _findAccount(accountId);
      if (account == null) {
        throw ValidationException(
          'MailRepository: аккаунт $accountId не найден',
        );
      }
      final isPrivate = account.isPrivateForLlm;
      final now = DateTime.now().toUtc();
      await _db.transaction(() async {
        for (final message in messages) {
          await _db
              .into(_db.mailMessages)
              .insert(
                db.MailMessagesCompanion.insert(
                  accountId: accountId,
                  remoteId: message.remoteId,
                  threadId: Value(message.threadId),
                  fromAddress: Value(message.fromAddress),
                  subject: Value(message.subject),
                  snippet: Value(message.snippet),
                  body: Value(message.body),
                  receivedAt: message.receivedAt.toUtc(),
                  isPrivateForLlm: Value(isPrivate || message.isPrivateForLlm),
                  createdAt: now,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      });
      return messages.length;
    });
  }

  @override
  Future<Result<void>> deleteMessage(int id) {
    return RepositoryGuard.guard('MailRepository.deleteMessage', () async {
      await (_db.delete(_db.mailMessages)..where((m) => m.id.equals(id))).go();
    });
  }

  Future<db.MailAccount?> _findAccount(int id) => (_db.select(
    _db.mailAccounts,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  String _newSecretRef() =>
      'mail.oauth.${DateTime.now().microsecondsSinceEpoch}'
      '.${_random.nextInt(1 << 32)}';

  static MailAccount _toAccount(db.MailAccount row) => MailAccount(
    id: row.id,
    provider: MailProviderType.fromDb(row.providerType),
    email: row.email,
    displayName: row.displayName,
    clientId: row.clientId,
    secretRef: row.secretRef,
    isPrivateForLlm: row.isPrivateForLlm,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  static MailMessage _toMessage(db.MailMessage row) => MailMessage(
    id: row.id,
    accountId: row.accountId,
    remoteId: row.remoteId,
    threadId: row.threadId,
    fromAddress: row.fromAddress,
    subject: row.subject,
    snippet: row.snippet,
    body: row.body,
    receivedAt: row.receivedAt,
    isPrivateForLlm: row.isPrivateForLlm,
    createdAt: row.createdAt,
  );
}
