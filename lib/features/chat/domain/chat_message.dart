import '../../llm/domain/llm_message.dart';

/// Сообщение чата, сохранённое в локальной БД.
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.errorCode,
    required this.createdAt,
  });

  final int id;
  final int threadId;
  final LlmRole role;
  final String content;
  final int? promptTokens;
  final int? completionTokens;
  final String? errorCode;
  final DateTime createdAt;
}

/// Данные для добавления сообщения.
final class ChatMessageDraft {
  const ChatMessageDraft({
    required this.threadId,
    required this.role,
    required this.content,
    this.promptTokens,
    this.completionTokens,
    this.errorCode,
  });

  final int threadId;
  final LlmRole role;
  final String content;
  final int? promptTokens;
  final int? completionTokens;
  final String? errorCode;
}
