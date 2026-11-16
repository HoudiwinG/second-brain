/// Письмо, сохранённое в локальном кэше.
class MailMessage {
  const MailMessage({
    required this.id,
    required this.accountId,
    required this.remoteId,
    required this.threadId,
    required this.fromAddress,
    required this.subject,
    required this.snippet,
    required this.body,
    required this.receivedAt,
    required this.isPrivateForLlm,
    required this.createdAt,
  });

  final int id;
  final int accountId;
  final String remoteId;
  final String? threadId;
  final String fromAddress;
  final String subject;
  final String snippet;
  final String body;
  final DateTime receivedAt;
  final bool isPrivateForLlm;
  final DateTime createdAt;

  String get displayTitle => subject.trim().isEmpty ? '(без темы)' : subject;
}

/// Данные письма для upsert в кэш.
class MailMessageDraft {
  const MailMessageDraft({
    required this.remoteId,
    this.threadId,
    required this.fromAddress,
    required this.subject,
    required this.snippet,
    required this.body,
    required this.receivedAt,
    this.isPrivateForLlm = false,
  });

  final String remoteId;
  final String? threadId;
  final String fromAddress;
  final String subject;
  final String snippet;
  final String body;
  final DateTime receivedAt;
  final bool isPrivateForLlm;
}
