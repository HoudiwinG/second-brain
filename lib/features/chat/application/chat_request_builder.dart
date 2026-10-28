import '../../llm/domain/llm_message.dart';
import '../domain/chat_message.dart';

/// Максимум сообщений истории, отправляемых в LLM.
const int maxHistoryMessages = 40;

/// Максимум символов истории (включая контекст), отправляемых в LLM.
const int maxHistoryChars = 60000;

/// Собирает сообщения запроса из локальной истории.
///
/// Правила:
/// - приватные сообщения и сообщения с ошибкой не отправляются;
/// - берётся хвост не длиннее [maxHistoryMessages] сообщений;
/// - общий размер не превышает [maxHistoryChars] символов;
/// - неудачная обрезка не оставляет историю, начинающуюся с assistant;
/// - подряд идущие сообщения одной роли склеиваются;
/// - контекст добавляется к последнему сообщению пользователя.
List<LlmMessage> buildChatRequestMessages(
  List<ChatMessage> history, {
  String contextText = '',
}) {
  final usable = history
      .where(
        (message) =>
            message.errorCode == null &&
            !message.isPrivateForLlm &&
            message.content.isNotEmpty,
      )
      .toList(growable: false);
  if (usable.isEmpty) return const [];

  final tail = usable.length > maxHistoryMessages
      ? usable.sublist(usable.length - maxHistoryMessages)
      : usable;

  var contextSuffix = '';
  final trimmedContext = contextText.trim();
  if (trimmedContext.isNotEmpty) {
    contextSuffix = '\n\n[context]\n$trimmedContext';
    if (contextSuffix.length > maxHistoryChars) {
      contextSuffix = contextSuffix.substring(0, maxHistoryChars);
    }
  }

  var budget = maxHistoryChars - contextSuffix.length;
  final selected = <ChatMessage>[];
  for (final message in tail.reversed) {
    var content = message.content;
    if (content.length > budget) {
      if (selected.isEmpty) {
        // Последнее сообщение важнее старых: сохраняем его хвост, но
        // не превышаем лимит.
        content = content.substring(content.length - budget);
        selected.add(
          ChatMessage(
            id: message.id,
            threadId: message.threadId,
            role: message.role,
            content: content,
            promptTokens: message.promptTokens,
            completionTokens: message.completionTokens,
            errorCode: message.errorCode,
            createdAt: message.createdAt,
            isPrivateForLlm: message.isPrivateForLlm,
          ),
        );
      }
      break;
    }
    selected.add(message);
    budget -= content.length;
  }

  final ordered = selected.reversed.toList(growable: false);
  final aligned = <LlmMessage>[];
  for (final message in ordered) {
    if (aligned.isEmpty && message.role != LlmRole.user) continue;
    final previous = aligned.isEmpty ? null : aligned.last;
    if (previous != null && previous.role == message.role) {
      aligned[aligned.length - 1] = LlmMessage(
        role: message.role,
        content: '${previous.content}\n\n${message.content}',
      );
    } else {
      aligned.add(LlmMessage(role: message.role, content: message.content));
    }
  }
  while (aligned.isNotEmpty && aligned.first.role != LlmRole.user) {
    aligned.removeAt(0);
  }
  if (aligned.isEmpty) return const [];

  if (contextSuffix.isNotEmpty) {
    final index = aligned.lastIndexWhere(
      (message) => message.role == LlmRole.user,
    );
    if (index >= 0) {
      aligned[index] = LlmMessage(
        role: aligned[index].role,
        content: '${aligned[index].content}$contextSuffix',
      );
    }
  }

  return _enforceCharLimit(aligned);
}

List<LlmMessage> _enforceCharLimit(List<LlmMessage> messages) {
  var total = messages.fold<int>(0, (sum, m) => sum + m.content.length);
  if (total <= maxHistoryChars) return messages;

  final result = [...messages];
  while (result.length > 1 && total > maxHistoryChars) {
    total -= result.first.content.length;
    result.removeAt(0);
  }
  while (result.isNotEmpty && result.first.role != LlmRole.user) {
    result.removeAt(0);
  }
  if (result.isEmpty) return const [];

  if (total > maxHistoryChars) {
    final last = result.last;
    final excess = total - maxHistoryChars;
    if (last.content.length <= excess) return const [];
    result[result.length - 1] = LlmMessage(
      role: last.role,
      content: last.content.substring(excess),
    );
  }
  return result;
}
