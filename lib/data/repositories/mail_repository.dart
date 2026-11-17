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
import '../search/search_index.dart';
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
      if (!draft.provider.available) {
        throw ValidationException(
          'MailRepository: ${draft.provider.label} недоступен',
        );
      }
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
      final existing =
          await (_db.select(_db.mailAccounts)..where(
                (t) =>
                    t.providerType.equals(draft.provider.dbValue) &
                    t.email.equals(email),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw ValidationException(
          'MailRepository: ящик ${draft.provider.label}/$email уже подключён',
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
    String? clientId,
    bool? isPrivateForLlm,
  }) {
    return RepositoryGuard.guard('MailRepository.updateAccount', () async {
      final current = await _findAccount(id);
      if (current == null) {
        throw ValidationException('MailRepository: аккаунт $id не найден');
      }
      if (clientId != null && clientId.trim().isEmpty) {
        throw const ValidationException(
          'MailRepository: OAuth client id не может быть пустым',
        );
      }
      await _db.transaction(() async {
        await (_db.update(
          _db.mailAccounts,
        )..where((t) => t.id.equals(id))).write(
          db.MailAccountsCompanion(
            displayName: displayName == null
                ? const Value.absent()
                : Value(displayName.trim()),
            clientId: clientId == null
                ? const Value.absent()
                : Value(clientId.trim()),
            isPrivateForLlm: isPrivateForLlm == null
                ? const Value.absent()
                : Value(isPrivateForLlm),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        if (isPrivateForLlm == true) {
          // Включение приватности ящика применяется к уже закэшированным
          // письмам. Выключение не сбрасывает индивидуальные флаги:
          // privacy всегда fail-closed.
          await (_db.update(
            _db.mailMessages,
          )..where((m) => m.accountId.equals(id))).write(
            const db.MailMessagesCompanion(isPrivateForLlm: Value(true)),
          );
        }
        final messages = await (_db.select(
          _db.mailMessages,
        )..where((m) => m.accountId.equals(id))).get();
        for (final message in messages) {
          await indexMailMessage(_db, message.id);
        }
      });
      final row = await _findAccount(id);
      return _toAccount(row!);
    });
  }

  @override
  Future<Result<void>> deleteAccount(int id) {
    return RepositoryGuard.guard('MailRepository.deleteAccount', () async {
      final current = await _findAccount(id);
      if (current == null) return;
      final messages = await (_db.select(
        _db.mailMessages,
      )..where((m) => m.accountId.equals(id))).get();
      await (_db.delete(_db.mailAccounts)..where((t) => t.id.equals(id))).go();
      await removeSearchEntries(
        _db,
        SearchEntityTypes.mail,
        messages.map((m) => m.id),
      );
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
      q.orderBy([
        (m) => OrderingTerm.desc(m.receivedAt),
        (m) => OrderingTerm.desc(m.id),
      ]);
      // SQLite LIKE не делает Unicode case-folding для кириллицы. Для
      // корректного поиска берём последние 5000 писем и фильтруем в Dart.
      q.limit(text == null || text.isEmpty ? limit.clamp(1, 200) : 5000);
      final rows = await q.get();
      final privateAccountIds = forLlm
          ? {
              for (final account in await _db.select(_db.mailAccounts).get())
                if (account.isPrivateForLlm) account.id,
            }
          : const <int>{};
      final filtered =
          (text == null || text.isEmpty
                  ? rows
                  : rows.where((row) {
                      final haystack =
                          '${row.subject} ${row.fromAddress} '
                                  '${row.snippet} ${row.body}'
                              .toLowerCase();
                      return haystack.contains(text.toLowerCase());
                    }).toList())
              .where((row) => !privateAccountIds.contains(row.accountId))
              .take(limit.clamp(1, 200))
              .toList();
      return [for (final row in filtered) _toMessage(row)];
    });
  }

  @override
  Future<Result<int>> countMessages({bool forLlm = false}) {
    return RepositoryGuard.guard('MailRepository.countMessages', () async {
      final query = _db.selectOnly(_db.mailMessages)
        ..addColumns([_db.mailMessages.id.count()]);
      if (forLlm) {
        query.where(_db.mailMessages.isPrivateForLlm.equals(false));
      }
      final row = await query.getSingle();
      return row.read(_db.mailMessages.id.count()) ?? 0;
    });
  }

  @override
  Future<Result<MailMessage?>> getMessage(int id) {
    return RepositoryGuard.guard('MailRepository.getMessage', () async {
      final row = await (_db.select(
        _db.mailMessages,
      )..where((m) => m.id.equals(id))).getSingleOrNull();
      if (row == null) return null;
      final account = await _findAccount(row.accountId);
      return _toMessage(row, forcePrivate: account?.isPrivateForLlm ?? false);
    });
  }

  @override
  Future<Result<MailMessage>> updateMessagePrivacy(int id, bool isPrivate) {
    return RepositoryGuard.guard(
      'MailRepository.updateMessagePrivacy',
      () async {
        final message = await (_db.select(
          _db.mailMessages,
        )..where((m) => m.id.equals(id))).getSingleOrNull();
        if (message == null) {
          throw ValidationException('MailRepository: письмо $id не найдено');
        }
        final account = await _findAccount(message.accountId);
        final effective = isPrivate || (account?.isPrivateForLlm ?? false);
        await (_db.update(_db.mailMessages)..where((m) => m.id.equals(id)))
            .write(db.MailMessagesCompanion(isPrivateForLlm: Value(effective)));
        await indexMailMessage(_db, id);
        final updated = await (_db.select(
          _db.mailMessages,
        )..where((m) => m.id.equals(id))).getSingle();
        return _toMessage(updated);
      },
    );
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
          final effectivePrivate = isPrivate || message.isPrivateForLlm;
          final existing =
              await (_db.select(_db.mailMessages)..where(
                    (m) =>
                        m.accountId.equals(accountId) &
                        m.remoteId.equals(message.remoteId),
                  ))
                  .getSingleOrNull();
          late final int messageId;
          if (existing == null) {
            messageId = await _db
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
                    isPrivateForLlm: Value(effectivePrivate),
                    createdAt: now,
                  ),
                );
          } else {
            messageId = existing.id;
            // Сохраняем id/created_at, чтобы UI-ссылки и кэш не «мигали».
            await (_db.update(
              _db.mailMessages,
            )..where((m) => m.id.equals(existing.id))).write(
              db.MailMessagesCompanion(
                threadId: Value(message.threadId),
                fromAddress: Value(message.fromAddress),
                subject: Value(message.subject),
                snippet: Value(message.snippet),
                body: Value(message.body),
                receivedAt: Value(message.receivedAt.toUtc()),
                isPrivateForLlm: Value(
                  effectivePrivate || existing.isPrivateForLlm,
                ),
              ),
            );
          }
          await indexMailMessage(_db, messageId);
        }
      });
      return messages.length;
    });
  }

  @override
  Future<Result<void>> deleteMessage(int id) {
    return RepositoryGuard.guard('MailRepository.deleteMessage', () async {
      await (_db.delete(_db.mailMessages)..where((m) => m.id.equals(id))).go();
      await removeSearchEntry(_db, SearchEntityTypes.mail, id);
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

  static MailMessage _toMessage(
    db.MailMessage row, {
    bool forcePrivate = false,
  }) => MailMessage(
    id: row.id,
    accountId: row.accountId,
    remoteId: row.remoteId,
    threadId: row.threadId,
    fromAddress: row.fromAddress,
    subject: row.subject,
    snippet: row.snippet,
    body: row.body,
    receivedAt: row.receivedAt,
    isPrivateForLlm: forcePrivate || row.isPrivateForLlm,
    createdAt: row.createdAt,
  );
}
