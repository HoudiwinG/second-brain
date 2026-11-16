import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/mail_repository.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';

import 'helpers/in_memory_db.dart';

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late DriftMailRepository repo;

  setUp(() {
    db = InMemoryDbFactory.open();
    secrets = InMemorySecretStore();
    addTearDown(db.close);
    addTearDown(secrets.clear);
    repo = DriftMailRepository(db, secrets);
  });

  Future<MailAccount> createAccount({bool private = false}) => repo
      .createAccount(
        MailAccountDraft(
          provider: MailProviderType.gmail,
          email: 'user@example.com',
          displayName: 'Рабочий',
          clientId: 'client-id',
          isPrivateForLlm: private,
        ),
      )
      .then((result) => (result as Success<MailAccount>).value);

  MailMessageDraft message(String id, {String subject = 'Тема'}) =>
      MailMessageDraft(
        remoteId: id,
        threadId: 'thread-1',
        fromAddress: 'sender@example.com',
        subject: subject,
        snippet: 'Кратко',
        body: 'Полный текст письма',
        receivedAt: DateTime.utc(2026, 11, 1, 10),
      );

  test('создаёт аккаунт с secretRef и не пишет токены в БД', () async {
    final created = await createAccount();
    expect(created.secretRef, isNotEmpty);
    expect(created.email, 'user@example.com');
    expect(created.clientId, 'client-id');
    final row = await db.select(db.mailAccounts).getSingle();
    expect(row.secretRef, created.secretRef);
    expect(row.email, 'user@example.com');
  });

  test('upsert писем, поиск и приватность аккаунта', () async {
    final publicAccount = await createAccount();
    final privateAccount = await createAccount(private: true);
    await repo.upsertMessages(publicAccount.id, [
      message('1', subject: 'Счёт'),
      message('2', subject: 'Встреча'),
    ]);
    await repo.upsertMessages(privateAccount.id, [
      message('3', subject: 'Секрет'),
    ]);

    final all = (await repo.listMessages()).unwrap();
    expect(all, hasLength(3));
    final visible = (await repo.listMessages(forLlm: true)).unwrap();
    expect(visible, hasLength(2));
    expect(visible.every((m) => !m.isPrivateForLlm), isTrue);
    final found = (await repo.listMessages(query: 'Счёт')).unwrap();
    expect(found.single.remoteId, '1');
    final privateFound = (await repo.listMessages(accountId: privateAccount.id))
        .unwrap();
    expect(privateFound.single.isPrivateForLlm, isTrue);
  });

  test('повторный upsert не создаёт дубликаты', () async {
    final account = await createAccount();
    await repo.upsertMessages(account.id, [message('1')]);
    await repo.upsertMessages(account.id, [
      message('1', subject: 'Новая тема'),
    ]);

    final messages = (await repo.listMessages()).unwrap();
    expect(messages, hasLength(1));
    expect(messages.single.subject, 'Новая тема');
  });

  test('удаление аккаунта каскадно удаляет письма и секрет', () async {
    final account = await createAccount();
    await secrets.write(account.secretRef, 'token');
    await repo.upsertMessages(account.id, [message('1')]);

    (await repo.deleteAccount(account.id)).unwrap();

    expect(await db.select(db.mailAccounts).get(), isEmpty);
    expect(await db.select(db.mailMessages).get(), isEmpty);
    expect(secrets.debugValues, isEmpty);
  });

  test('валидация email и client id', () async {
    expect(
      await repo.createAccount(
        const MailAccountDraft(
          provider: MailProviderType.gmail,
          email: 'not-email',
          clientId: 'client',
        ),
      ),
      isA<Failure<MailAccount>>(),
    );
    expect(
      await repo.createAccount(
        const MailAccountDraft(
          provider: MailProviderType.gmail,
          email: 'user@example.com',
          clientId: ' ',
        ),
      ),
      isA<Failure<MailAccount>>(),
    );
  });
}
