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
    final toolCallBuilders = <int, _ToolCallBuilder>{};
    try {
      await for (final chunk in streamChat(request)) {
        buffer.write(chunk.delta);
        if (chunk.usage != null) usage = usage.merge(chunk.usage!);
        for (final delta in chunk.toolCallDeltas) {
          final builder = toolCallBuilders.putIfAbsent(
            delta.index,
            _ToolCallBuilder.new,
          );
          builder.apply(delta);
        }
      }
      return Result.success(
        LlmResponse(
          content: buffer.toString(),
          usage: usage,
          toolCalls: [
            for (final entry in toolCallBuilders.entries)
              if (entry.value.id != null && entry.value.name != null)
                LlmToolCall(
                  id: entry.value.id!,
                  name: entry.value.name!,
                  argumentsJson: entry.value.arguments.isEmpty
                      ? '{}'
                      : entry.value.arguments,
                ),
          ],
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
  Future<Result<List<double>>> embed(String input) async => const Result.failure(
    LlmException('LLM: провайдер не поддерживает embeddings'),
  );
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
