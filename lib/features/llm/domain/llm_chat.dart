import 'llm_message.dart';
import 'llm_tool.dart';

/// Запрос к LLM.
final class LlmChatRequest {
  const LlmChatRequest({
    required this.model,
    required this.messages,
    this.maxTokens = 1024,
    this.temperature,
    this.tools = const [],
  });

  final String model;
  final List<LlmMessage> messages;

  /// Жёсткий лимит ответа: защищает от случайного большого счёта.
  final int maxTokens;

  final double? temperature;
  final List<LlmToolDefinition> tools;
}

/// Токены, использованные запросом.
final class LlmUsage {
  const LlmUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  LlmUsage merge(LlmUsage other) => LlmUsage(
    promptTokens: other.promptTokens ?? promptTokens,
    completionTokens: other.completionTokens ?? completionTokens,
    totalTokens: other.totalTokens ?? totalTokens,
  );
}

/// Элемент streaming-ответа.
final class LlmChunk {
  const LlmChunk({
    this.delta = '',
    this.done = false,
    this.usage,
    this.toolCallDeltas = const [],
  });

  /// Приращение текста ответа.
  final String delta;

  /// Последний чанк: поток завершён.
  final bool done;

  final LlmUsage? usage;

  /// Приращения tool-call'ов; собираются в [LlmResponse.toolCalls].
  final List<LlmToolCallDelta> toolCallDeltas;
}

/// Собранный ответ провайдера.
final class LlmResponse {
  const LlmResponse({
    required this.content,
    required this.usage,
    this.toolCalls = const [],
  });

  final String content;
  final LlmUsage usage;
  final List<LlmToolCall> toolCalls;
}
