import 'llm_tool.dart';

/// Роль сообщения в диалоге.
enum LlmRole {
  system('system'),
  user('user'),
  assistant('assistant'),
  tool('tool');

  const LlmRole(this.dbValue);

  final String dbValue;

  static LlmRole fromDb(String raw) => LlmRole.values.firstWhere(
    (role) => role.dbValue == raw,
    orElse: () => LlmRole.user,
  );
}

/// Сообщение диалога, независимое от конкретного провайдера.
final class LlmMessage {
  const LlmMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCallId,
    this.toolCalls = const [],
  });

  final LlmRole role;
  final String content;

  /// Имя инструмента для role=tool.
  final String? name;

  /// Идентификатор вызова для role=tool.
  final String? toolCallId;

  /// Вызовы инструментов, возвращённые ассистентом.
  final List<LlmToolCall> toolCalls;

  /// Формат OpenAI-compatible.
  Map<String, Object?> toOpenAiJson() {
    final json = <String, Object?>{'role': role.dbValue, 'content': content};
    if (name != null) json['name'] = name;
    if (toolCallId != null) json['tool_call_id'] = toolCallId;
    if (toolCalls.isNotEmpty) {
      json['tool_calls'] = [
        for (final call in toolCalls)
          {
            'id': call.id,
            'type': 'function',
            'function': {
              'name': call.name,
              'arguments': call.argumentsJson,
            },
          },
      ];
    }
    return json;
  }
}
