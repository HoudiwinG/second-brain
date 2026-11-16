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
        'Authorization': '${tokens.tokenType} ${tokens.accessToken}',
      },
      client: client,
      delay: delay,
    );
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
    final ids = list.when(
      success: (value) => value,
      failure: (error) => throw error,
    );
    final messages = <MailMessageDraft>[];
    for (final id in ids) {
      final message = await api.requestJson<MailMessageDraft>(
        method: 'GET',
        path: '/users/me/messages/${Uri.encodeComponent(id)}?format=full',
        parse: (json) => _parseMessage(account, json),
      );
      message.when(success: messages.add, failure: (error) => throw error);
    }
    return Result.success(messages);
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
    final mime = payload['mimeType'];
    if (mime == 'text/plain') {
      final body = payload['body'];
      if (body is Map<String, Object?> && body['data'] is String) {
        return _decodeBase64(body['data']! as String);
      }
    }
    final parts = payload['parts'];
    if (parts is List) {
      final texts = <String>[];
      for (final part in parts) {
        final text = _payloadText(part);
        if (text.trim().isNotEmpty) texts.add(text);
      }
      if (texts.isNotEmpty) return texts.join('\n');
    }
    final body = payload['body'];
    if (body is Map<String, Object?> && body['data'] is String) {
      return _decodeBase64(body['data']! as String);
    }
    return '';
  }

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

/// Универсальный REST-адаптер для Yandex/Mail.ru.
///
/// Официальные API отличаются от Gmail; адаптер ожидает контракт
/// `GET /messages?limit=&q=` → `{messages: [...]}`. Точные эндпоинты
/// задаются в [MailProviderType]; живые вызовы требуют проверки.
class RestMailProvider implements MailProvider {
  RestMailProvider({this.client, this.delay});

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
        'Authorization': '${tokens.tokenType} ${tokens.accessToken}',
      },
      client: client,
      delay: delay,
    );
    final q = query?.trim();
    final path =
        '/messages?limit=${limit.clamp(1, 50)}'
        '${q == null || q.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(q)}'}';
    return api.requestJson<List<MailMessageDraft>>(
      method: 'GET',
      path: path,
      parse: (json) {
        if (json is! Map<String, Object?>) {
          throw const LlmException('Mail: некорректный список писем');
        }
        final raw = json['messages'];
        if (raw is! List) return const [];
        return [
          for (final item in raw)
            if (item is Map<String, Object?> && item['id'] is String)
              MailMessageDraft(
                remoteId: item['id']! as String,
                threadId: item['thread_id'] is String
                    ? item['thread_id']! as String
                    : null,
                fromAddress: item['from'] is String
                    ? item['from']! as String
                    : '',
                subject: item['subject'] is String
                    ? item['subject']! as String
                    : '',
                snippet: item['snippet'] is String
                    ? item['snippet']! as String
                    : '',
                body: item['body'] is String ? item['body']! as String : '',
                receivedAt:
                    _parseDate(item['received_at']) ?? DateTime.now().toUtc(),
                isPrivateForLlm: account.isPrivateForLlm,
              ),
        ];
      },
    );
  }

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
  MailProviderType.yandex ||
  MailProviderType.mailru => RestMailProvider(client: client, delay: delay),
};
