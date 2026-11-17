import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/data/db/app_database.dart'
    show AppDatabase, MailMessagesCompanion;
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

  Future<MailAccount> createAccount({
    bool private = false,
    String email = 'user@example.com',
  }) => repo
      .createAccount(
        MailAccountDraft(
          provider: MailProviderType.gmail,
          email: email,
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
    final privateAccount = await createAccount(
      private: true,
      email: 'private@example.com',
    );
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

  test('приватность ящика применяется к уже сохранённым письмам', () async {
    final account = await createAccount();
    await repo.upsertMessages(account.id, [message('1')]);
    expect((await repo.listMessages(forLlm: true)).unwrap(), hasLength(1));

    (await repo.updateAccount(account.id, isPrivateForLlm: true)).unwrap();

    final stored = (await repo.listMessages()).unwrap().single;
    expect(stored.isPrivateForLlm, isTrue);
    expect((await repo.listMessages(forLlm: true)).unwrap(), isEmpty);

    // Выключение privacy ящика не сбрасывает индивидуальный флаг письма.
    (await repo.updateAccount(account.id, isPrivateForLlm: false)).unwrap();
    expect((await repo.listMessages()).unwrap().single.isPrivateForLlm, isTrue);
  });

  test('нельзя подключить один и тот же ящик дважды', () async {
    await createAccount();
    final duplicate = await repo.createAccount(
      const MailAccountDraft(
        provider: MailProviderType.gmail,
        email: 'USER@example.com',
        clientId: 'other-client',
      ),
    );
    expect(duplicate, isA<Failure<MailAccount>>());
    expect((await repo.listAccounts()).unwrap(), hasLength(1));
  });

  test('приватность отдельного письма управляется независимо', () async {
    final account = await createAccount();
    await repo.upsertMessages(account.id, [message('1'), message('2')]);
    final first = (await repo.listMessages()).unwrap().firstWhere(
      (m) => m.remoteId == '1',
    );

    final updated = (await repo.updateMessagePrivacy(first.id, true)).unwrap();
    expect(updated.isPrivateForLlm, isTrue);
    final visible = (await repo.listMessages(forLlm: true)).unwrap();
    expect(visible.map((m) => m.remoteId), ['2']);
  });

  test('countMessages считает кэш и privacy-фильтр', () async {
    final account = await createAccount();
    await repo.upsertMessages(account.id, [message('1'), message('2')]);
    expect((await repo.countMessages()).unwrap(), 2);
    expect((await repo.countMessages(forLlm: true)).unwrap(), 2);
    (await repo.updateAccount(account.id, isPrivateForLlm: true)).unwrap();
    expect((await repo.countMessages(forLlm: true)).unwrap(), 0);
  });

  test('повторный upsert не создаёт дубликаты', () async {
    final account = await createAccount();
    await repo.upsertMessages(account.id, [message('1')]);
    final first = (await repo.listMessages()).unwrap().single;
    await repo.upsertMessages(account.id, [
      message('1', subject: 'Новая тема'),
    ]);

    final messages = (await repo.listMessages()).unwrap();
    expect(messages, hasLength(1));
    expect(messages.single.subject, 'Новая тема');
    expect(messages.single.id, first.id);
    expect(messages.single.createdAt, first.createdAt);
  });

  test('private ящик защищает письмо даже с false-флагом из backup', () async {
    final account = await createAccount(private: true);
    await repo.upsertMessages(account.id, [message('1')]);
    // Имитация старого/отредактированного backup: флаг письма false.
    await (db.update(db.mailMessages)
          ..where((m) => m.accountId.equals(account.id)))
        .write(const MailMessagesCompanion(isPrivateForLlm: Value(false)));

    expect((await repo.listMessages(forLlm: true)).unwrap(), isEmpty);
    final stored = (await repo.getMessage(
      (await repo.listMessages()).unwrap().single.id,
    )).unwrap()!;
    expect(stored.isPrivateForLlm, isTrue);
  });

  test('поиск по кириллице не зависит от регистра', () async {
    final account = await createAccount();
    await repo.upsertMessages(account.id, [message('1', subject: 'Счёт')]);
    final found = (await repo.listMessages(query: 'счёт')).unwrap();
    expect(found.single.remoteId, '1');
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
