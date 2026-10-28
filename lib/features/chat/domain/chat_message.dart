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
    this.isPrivateForLlm = false,
  });

  final int id;
  final int threadId;
  final LlmRole role;
  final String content;
  final int? promptTokens;
  final int? completionTokens;
  final String? errorCode;
  final DateTime createdAt;

  /// true — сообщение не включается в контекст следующих запросов.
  final bool isPrivateForLlm;

  ChatMessage copyWith({bool? isPrivateForLlm}) => ChatMessage(
    id: id,
    threadId: threadId,
    role: role,
    content: content,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    errorCode: errorCode,
    createdAt: createdAt,
    isPrivateForLlm: isPrivateForLlm ?? this.isPrivateForLlm,
  );
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
    this.isPrivateForLlm = false,
  });

  final int threadId;
  final LlmRole role;
  final String content;
  final int? promptTokens;
  final int? completionTokens;
  final String? errorCode;
  final bool isPrivateForLlm;
}
