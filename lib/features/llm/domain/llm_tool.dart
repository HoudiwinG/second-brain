/// Описание инструмента, который можно передать LLM.
///
/// На stage-03 это только контракт и сериализация: исполнение инструментов
/// и аудит появятся на stage-04.
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
