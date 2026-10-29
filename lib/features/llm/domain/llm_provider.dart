import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import 'llm_chat.dart';
import 'llm_provider_config.dart';
import 'llm_tool.dart';

/// Контракт LLM-провайдера.
///
/// Провайдер умеет отдавать ответ потоком (для UI) и целиком (для тестов /
/// фоновых задач). Ошибки сети и API должны приходить как [LlmException]
/// или [NetworkException] — без секретов и содержимого приватных сущностей.
abstract class LlmProvider {
  LlmProvider(this.config);

  final LlmProviderConfig config;

  /// Стриминг ответа. Отмена подписки прекращает чтение HTTP-потока.
  Stream<LlmChunk> streamChat(LlmChatRequest request);

  /// Собирает streaming-ответ в один объект.
  Future<Result<LlmResponse>> complete(LlmChatRequest request) async {
    final buffer = StringBuffer();
    var usage = const LlmUsage();
    final toolCalls = LlmToolCallAccumulator();
    try {
      await for (final chunk in streamChat(request)) {
        buffer.write(chunk.delta);
        if (chunk.usage != null) usage = usage.merge(chunk.usage!);
        toolCalls.addAll(chunk.toolCallDeltas);
      }
      return Result.success(
        LlmResponse(
          content: buffer.toString(),
          usage: usage,
          toolCalls: toolCalls.build(),
        ),
      );
    } on AppException catch (e) {
      return Result.failure(e);
    } on Object catch (e, s) {
      return Result.failure(
        LlmException(
          'LLM: не удалось получить ответ провайдера',
          cause: e,
          stackTrace: s,
        ),
      );
    }
  }

  /// Эмбеддинги текста. Провайдеры без embeddings возвращают ошибку.
  Future<Result<List<double>>> embed(String input) async =>
      const Result.failure(
        LlmException('LLM: провайдер не поддерживает embeddings'),
      );
}

/// Собирает приращения tool-call'ов из streaming-чанков в завершённые вызовы.
final class LlmToolCallAccumulator {
  final Map<int, _ToolCallBuilder> _builders = {};

  void addAll(Iterable<LlmToolCallDelta> deltas) {
    for (final delta in deltas) {
      _builders.putIfAbsent(delta.index, _ToolCallBuilder.new).apply(delta);
    }
  }

  /// Вызовы без id или имени отбрасываются: их нельзя выполнить.
  List<LlmToolCall> build() => [
    for (final builder in _builders.values)
      if (builder.id != null && builder.name != null)
        LlmToolCall(
          id: builder.id!,
          name: builder.name!,
          argumentsJson: builder.arguments.isEmpty ? '{}' : builder.arguments,
        ),
  ];
}

final class _ToolCallBuilder {
  String? id;
  String? name;
  String arguments = '';

  void apply(LlmToolCallDelta delta) {
    id ??= delta.id;
    name ??= delta.name;
    arguments += delta.argumentsJson ?? '';
  }
}
