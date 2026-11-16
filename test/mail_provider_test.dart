import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/features/mail/application/mail_oauth.dart';
import 'package:second_brain/features/mail/data/mail_provider.dart';
import 'package:second_brain/features/mail/domain/mail_account.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';
import 'package:second_brain/features/mail/domain/mail_provider_type.dart';

MailAccount _account({bool private = false}) => MailAccount(
  id: 1,
  provider: MailProviderType.gmail,
  email: 'user@example.com',
  displayName: '',
  clientId: 'client',
  secretRef: 'secret',
  isPrivateForLlm: private,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

MailTokens _tokens() =>
    MailTokens(accessToken: 'access', expiresAt: DateTime.utc(2030, 1, 1));

void main() {
  test('Gmail: список + разбор письма', () async {
    final body = base64Url.encode(utf8.encode('Текст письма'));
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer access');
      if (request.url.path.endsWith('/messages')) {
        return http.Response(
          jsonEncode({
            'messages': [
              {'id': 'm1'},
            ],
          }),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 'm1',
            'threadId': 't1',
            'internalDate': '1762000000000',
            'snippet': 'Кратко',
            'payload': {
              'mimeType': 'text/plain',
              'headers': [
                {'name': 'From', 'value': 'sender@example.com'},
                {'name': 'Subject', 'value': 'Тема'},
              ],
              'body': {'data': body},
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final provider = GmailMailProvider(client: client, delay: (_) async {});

    final result = await provider.fetchMessages(
      account: _account(),
      tokens: _tokens(),
    );

    final messages = (result as Success<List<MailMessageDraft>>).value;
    expect(messages, hasLength(1));
    expect(messages.single.remoteId, 'm1');
    expect(messages.single.threadId, 't1');
    expect(messages.single.subject, 'Тема');
    expect(messages.single.body, 'Текст письма');
    expect(messages.single.isPrivateForLlm, isFalse);
  });

  test('Gmail: multipart/alternative выбирает plain, а не HTML', () async {
    String part(String mime, String text) =>
        base64Url.encode(utf8.encode(text));
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/messages')) {
        return http.Response('{"messages":[{"id":"m1"}]}', 200);
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 'm1',
            'snippet': 'Кратко',
            'payload': {
              'mimeType': 'multipart/alternative',
              'headers': [
                {'name': 'Subject', 'value': 'Тема'},
              ],
              'parts': [
                {
                  'mimeType': 'text/plain',
                  'body': {'data': part('text/plain', 'Plain текст')},
                },
                {
                  'mimeType': 'text/html',
                  'body': {'data': part('text/html', '<p>HTML текст</p>')},
                },
              ],
            },
          }),
        ),
        200,
      );
    });
    final provider = GmailMailProvider(client: client, delay: (_) async {});
    final result = await provider.fetchMessages(
      account: _account(),
      tokens: _tokens(),
    );
    final body = (result as Success<List<MailMessageDraft>>).value.single.body;
    expect(body, 'Plain текст');
    expect(body, isNot(contains('HTML текст')));
    expect(body, isNot(contains('<p>')));
  });

  test('Gmail: multipart/mixed пропускает вложения', () async {
    String part(String mime, String text) =>
        base64Url.encode(utf8.encode(text));
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/messages')) {
        return http.Response('{"messages":[{"id":"m1"}]}', 200);
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 'm1',
            'payload': {
              'mimeType': 'multipart/mixed',
              'parts': [
                {
                  'mimeType': 'text/plain',
                  'body': {'data': part('text/plain', 'Текст письма')},
                },
                {
                  'mimeType': 'text/plain',
                  'filename': 'secret.txt',
                  'body': {'data': part('text/plain', 'Вложение')},
                },
              ],
            },
          }),
        ),
        200,
      );
    });
    final provider = GmailMailProvider(client: client, delay: (_) async {});
    final result = await provider.fetchMessages(
      account: _account(),
      tokens: _tokens(),
    );
    final body = (result as Success<List<MailMessageDraft>>).value.single.body;
    expect(body, 'Текст письма');
    expect(body, isNot(contains('Вложение')));
  });

  test('Gmail: приватный аккаунт помечает письма приватными', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/messages')) {
        return http.Response('{"messages":[{"id":"m1"}]}', 200);
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 'm1',
            'snippet': 'Кратко',
            'payload': {
              'headers': [
                {'name': 'Subject', 'value': 'Тема'},
              ],
            },
          }),
        ),
        200,
      );
    });
    final provider = GmailMailProvider(client: client, delay: (_) async {});
    final result = await provider.fetchMessages(
      account: _account(private: true),
      tokens: _tokens(),
    );
    final messages = (result as Success<List<MailMessageDraft>>).value;
    expect(messages.single.isPrivateForLlm, isTrue);
  });

  test('Yandex: конверты Inbox и text-parts', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/folders/1/envelopes')) {
        expect(request.headers['Authorization'], 'OAuth access');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'items': [
                {
                  'message_id': 'm1',
                  'thread_id': 't1',
                  'received_at': '2026-11-01T10:00:00+00:00',
                  'subject': 'Тема',
                  'firstline': 'Превью',
                  'from': [
                    {'local': 'sender', 'domain': 'example.com'},
                  ],
                },
              ],
            }),
          ),
          200,
        );
      }
      expect(request.url.path, '/v1/mail/messages/m1/text-parts');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'items': [
              {'body': '<p>Текст</p><p>письма</p>'},
            ],
          }),
        ),
        200,
      );
    });
    final account = MailAccount(
      id: 2,
      provider: MailProviderType.yandex,
      email: 'user@yandex.ru',
      displayName: '',
      clientId: 'client',
      secretRef: 'secret',
      isPrivateForLlm: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final provider = YandexMailProvider(client: client, delay: (_) async {});

    final result = await provider.fetchMessages(
      account: account,
      tokens: _tokens(),
    );

    final messages = (result as Success<List<MailMessageDraft>>).value;
    expect(messages.single.remoteId, 'm1');
    expect(messages.single.subject, 'Тема');
    expect(messages.single.fromAddress, 'sender@example.com');
    expect(messages.single.body, 'Текст письма');
  });
}
