import 'dart:convert';

/// Декодирует аргументы вызова инструмента. Некорректный JSON даёт пустой
/// объект: инструмент тогда получит пустые аргументы и вернёт ошибку.
Map<String, Object?> decodeToolArguments(String json) {
  try {
    final decoded = jsonDecode(json);
    return decoded is Map<String, Object?> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

/// Описание инструмента, который можно передать LLM.
///
/// Контракт и сериализация для всех провайдеров; исполнение инструментов —
/// в `ToolRunner` (stage-04).
final class LlmToolDefinition {
  const LlmToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON Schema параметров инструмента.
  final Map<String, Object?> parameters;

  /// Формат OpenAI-compatible `tools[]`.
  Map<String, Object?> toOpenAiJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };

  /// Формат Anthropic `tools[]`.
  Map<String, Object?> toAnthropicJson() => {
    'name': name,
    'description': description,
    'input_schema': parameters,
  };

  /// Формат Google `functionDeclarations[]`.
  Map<String, Object?> toGoogleJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

/// Завершённый вызов инструмента.
final class LlmToolCall {
  const LlmToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  final String id;
  final String name;

  /// Аргументы в виде JSON-строки — так их возвращает streaming API.
  final String argumentsJson;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlmToolCall &&
          other.id == id &&
          other.name == name &&
          other.argumentsJson == argumentsJson;

  @override
  int get hashCode => Object.hash(id, name, argumentsJson);
}

/// Фрагмент вызова инструмента в SSE-потоке.
final class LlmToolCallDelta {
  const LlmToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.argumentsJson,
  });

  final int index;
  final String? id;
  final String? name;
  final String? argumentsJson;
}
