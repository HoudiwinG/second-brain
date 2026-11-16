import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../application/mail_oauth.dart';
import '../domain/mail_account.dart';
import '../domain/mail_message.dart';
import '../domain/mail_provider_type.dart';

/// Контракт чтения почты через официальный REST API провайдера.
abstract interface class MailProvider {
  Future<Result<List<MailMessageDraft>>> fetchMessages({
    required MailAccount account,
    required MailTokens tokens,
    String? query,
    int limit = 20,
  });
}

/// Gmail API (users.messages.list + get format=full).
class GmailMailProvider implements MailProvider {
  GmailMailProvider({this.client, this.delay});

  final http.Client? client;
  final Future<void> Function(Duration)? delay;

  @override
  Future<Result<List<MailMessageDraft>>> fetchMessages({
    required MailAccount account,
    required MailTokens tokens,
    String? query,
    int limit = 20,
  }) async {
    final api = ApiClient(
      baseUrl: account.provider.apiBaseUrl,
      maxRetries: 2,
      headersProvider: () => {
        'Authorization': '${account.provider.authScheme} ${tokens.accessToken}',
      },
      client: client,
      delay: delay,
    );
    try {
      final safeLimit = limit.clamp(1, 50);
      final q = query?.trim();
      final path =
          '/users/me/messages?maxResults=$safeLimit'
          '${q == null || q.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(q)}'}';
      final list = await api.requestJson<List<String>>(
        method: 'GET',
        path: path,
        parse: (json) {
          if (json is! Map<String, Object?>) {
            throw const LlmException('Gmail: некорректный список писем');
          }
          final raw = json['messages'];
          if (raw is! List) return const [];
          return [
            for (final item in raw)
              if (item is Map<String, Object?> && item['id'] is String)
                item['id']! as String,
          ];
        },
      );
      if (list is Failure<List<String>>) {
        return Result.failure(list.error);
      }
      final ids = (list as Success<List<String>>).value;
      final messages = <MailMessageDraft>[];
      for (final id in ids) {
        final message = await api.requestJson<MailMessageDraft>(
          method: 'GET',
          path: '/users/me/messages/${Uri.encodeComponent(id)}?format=full',
          parse: (json) => _parseMessage(account, json),
        );
        if (message is Failure<MailMessageDraft>) {
          return Result.failure(message.error);
        }
        messages.add((message as Success<MailMessageDraft>).value);
      }
      return Result.success(messages);
    } finally {
      api.close();
    }
  }

  MailMessageDraft _parseMessage(MailAccount account, Object? json) {
    if (json is! Map<String, Object?>) {
      throw const LlmException('Gmail: некорректное письмо');
    }
    final payload = json['payload'];
    final headers = <String, String>{};
    if (payload is Map<String, Object?> && payload['headers'] is List) {
      for (final raw in payload['headers']! as List) {
        if (raw is Map<String, Object?> &&
            raw['name'] is String &&
            raw['value'] is String) {
          headers[(raw['name']! as String).toLowerCase()] =
              raw['value']! as String;
        }
      }
    }
    final internal = json['internalDate'];
    final internalMs = internal is String ? int.tryParse(internal) : null;
    final receivedAt = internalMs != null && internalMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(internalMs, isUtc: true)
        : _parseDate(headers['date']) ?? DateTime.now().toUtc();
    return MailMessageDraft(
      remoteId: json['id'] is String ? json['id']! as String : '',
      threadId: json['threadId'] is String ? json['threadId']! as String : null,
      fromAddress: headers['from'] ?? '',
      subject: headers['subject'] ?? '',
      snippet: json['snippet'] is String ? json['snippet']! as String : '',
      body: _payloadText(payload),
      receivedAt: receivedAt.toUtc(),
      isPrivateForLlm: account.isPrivateForLlm,
    );
  }

  static String _payloadText(Object? payload) {
    if (payload is! Map<String, Object?>) return '';
    final filename = payload['filename'];
    if (filename is String && filename.isNotEmpty) return '';
    final mime = payload['mimeType'] is String
        ? payload['mimeType']! as String
        : '';
    if (mime.startsWith('multipart/')) {
      // multipart/alternative: выбираем text/plain и не склеиваем с HTML.
      // multipart/mixed: также предпочитаем plain, вложения пропускаем.
      final plain = _findPartText(payload, 'text/plain');
      if (plain != null) return plain;
      final html = _findPartText(payload, 'text/html');
      if (html != null) return _htmlToText(html);
      return '';
    }
    final body = payload['body'];
    if (body is Map<String, Object?> && body['data'] is String) {
      final text = _decodeBase64(body['data']! as String);
      return mime == 'text/html' ? _htmlToText(text) : text;
    }
    return '';
  }

  /// Ищет первую непустую текстовую часть нужного MIME-типа.
  static String? _findPartText(Object? part, String targetMime) {
    if (part is! Map<String, Object?>) return null;
    final filename = part['filename'];
    if (filename is String && filename.isNotEmpty) return null;
    final mime = part['mimeType'] is String ? part['mimeType']! as String : '';
    if (mime == targetMime) {
      final body = part['body'];
      if (body is Map<String, Object?> && body['data'] is String) {
        final text = _decodeBase64(body['data']! as String);
        return text.trim().isEmpty ? null : text;
      }
    }
    final parts = part['parts'];
    if (parts is List) {
      for (final child in parts) {
        final found = _findPartText(child, targetMime);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String _htmlToText(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static String _decodeBase64(String raw) {
    try {
      return utf8.decode(base64Url.decode(base64Url.normalize(raw)));
    } on FormatException {
      return '';
    }
  }

  static DateTime? _parseDate(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

/// Yandex 360 Mail API: папка Inbox (`1`) + текстовые части письма.
///
/// Контракт:
/// - https://yandex.ru/dev/yandex-360/mail/ru/api/folders/get-envelopes.md
/// - https://yandex.ru/dev/yandex-360/mail/ru/api/messages/get-text-parts.md
/// Базовый URL: `https://cloud-api.yandex.net/v1/mail`.
/// Серверного поиска в API нет, поэтому query фильтрует уже полученную
/// страницу; локальный кэш ищет по сохранённым письмам.
class YandexMailProvider implements MailProvider {
  YandexMailProvider({this.client, this.delay});

  final http.Client? client;
  final Future<void> Function(Duration)? delay;

  @override
  Future<Result<List<MailMessageDraft>>> fetchMessages({
    required MailAccount account,
    required MailTokens tokens,
    String? query,
    int limit = 20,
  }) async {
    final api = ApiClient(
      baseUrl: account.provider.apiBaseUrl,
      maxRetries: 2,
      headersProvider: () => {
        'Authorization': '${account.provider.authScheme} ${tokens.accessToken}',
      },
      client: client,
      delay: delay,
    );
    try {
      final safeLimit = limit.clamp(1, 50);
      final envelopes = await api.requestJson<List<Map<String, Object?>>>(
        method: 'GET',
        path: '/folders/1/envelopes?limit=$safeLimit&offset=0',
        parse: (json) {
          if (json is! Map<String, Object?>) {
            throw const LlmException('Yandex Mail: некорректный ответ');
          }
          final raw = json['items'];
          if (raw is! List) {
            throw const LlmException('Yandex Mail: в ответе нет items');
          }
          return [
            for (final item in raw)
              if (item is Map<String, Object?>) item,
          ];
        },
      );
      if (envelopes is Failure<List<Map<String, Object?>>>) {
        return Result.failure(envelopes.error);
      }
      final items = (envelopes as Success<List<Map<String, Object?>>>).value;
      final q = query?.trim().toLowerCase();
      final messages = <MailMessageDraft>[];
      for (final item in items) {
        if (messages.length >= safeLimit) break;
        final id = item['message_id'];
        if (id is! String || id.isEmpty) {
          throw const LlmException('Yandex Mail: нет message_id');
        }
        final from = _address(item['from']);
        final subject = item['subject'] is String
            ? item['subject']! as String
            : '';
        final snippet = item['firstline'] is String
            ? item['firstline']! as String
            : '';
        if (q != null &&
            q.isNotEmpty &&
            !'$from $subject $snippet'.toLowerCase().contains(q)) {
          continue;
        }
        final text = await api.requestJson<String>(
          method: 'GET',
          path: '/messages/${Uri.encodeComponent(id)}/text-parts',
          parse: (json) {
            if (json is! Map<String, Object?>) {
              throw const LlmException(
                'Yandex Mail: некорректный текст письма',
              );
            }
            final parts = json['items'];
            if (parts is! List) return '';
            return [
              for (final part in parts)
                if (part is Map<String, Object?> && part['body'] is String)
                  part['body']! as String,
            ].join('\n');
          },
        );
        if (text is Failure<String>) {
          return Result.failure(text.error);
        }
        final body = _plainText((text as Success<String>).value);
        messages.add(
          MailMessageDraft(
            remoteId: id,
            threadId: item['thread_id'] is String
                ? item['thread_id']! as String
                : null,
            fromAddress: from,
            subject: subject,
            snippet: snippet,
            body: body,
            receivedAt:
                _parseDate(item['received_at']) ?? DateTime.now().toUtc(),
            isPrivateForLlm: account.isPrivateForLlm,
          ),
        );
      }
      return Result.success(messages);
    } finally {
      api.close();
    }
  }

  static String _address(Object? raw) {
    if (raw is! List || raw.isEmpty) return '';
    final first = raw.first;
    if (first is! Map<String, Object?>) return '';
    final local = first['local'];
    final domain = first['domain'];
    if (local is String && domain is String) return '$local@$domain';
    return first['display_name'] is String
        ? first['display_name']! as String
        : '';
  }

  static String _plainText(String html) => html
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
}

/// Выбор адаптера по типу провайдера.
MailProvider createMailProvider(
  MailAccount account, {
  http.Client? client,
  Future<void> Function(Duration)? delay,
}) => switch (account.provider) {
  MailProviderType.gmail => GmailMailProvider(client: client, delay: delay),
  MailProviderType.yandex => YandexMailProvider(client: client, delay: delay),
  MailProviderType.mailru => throw const ValidationException(
    'Mail.ru не предоставляет официальный REST API чтения писем; '
    'подключение отключено',
  ),
};
