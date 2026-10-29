import '../../../../core/result/result.dart';
import '../llm_tool_registry.dart';
import 'tool_args.dart';

/// Выдаёт письма из фиксированного мок-набора. Реальная почта — stage-06
/// (OAuth), поэтому данные не зависят от аккаунта пользователя.
final class SummarizeMailMockTool extends LlmToolBase {
  const SummarizeMailMockTool();

  static const _mockMessages = [
    {
      'from': 'billing@example.test',
      'subject': 'Счёт за услуги за октябрь',
      'received_at': '2026-10-27T09:00:00',
      'snippet': 'Счёт на 1 200 руб. Срок оплаты — 10 ноября.',
    },
    {
      'from': 'team@example.test',
      'subject': 'Встреча переносится на четверг',
      'received_at': '2026-10-28T14:30:00',
      'snippet': 'Созвон по проекту перенесён на четверг, 15:00.',
    },
    {
      'from': 'news@example.test',
      'subject': 'Новости недели',
      'received_at': '2026-10-28T08:00:00',
      'snippet': 'Подборка статей и обновлений без действий.',
    },
  ];

  @override
  String get name => 'summarize_mail_mock';

  @override
  String get description =>
      'Получить последние письма (тестовые данные) для суммирования. Ответ '
      'помечен source = mock.';

  @override
  Map<String, Object?> get parameters => {
    'type': 'object',
    'properties': {
      'limit': {'type': 'integer', 'description': 'Максимум писем, до 10'},
    },
  };

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async {
    try {
      final limit = (ToolArgs.optionalInt(arguments, 'limit') ?? 10).clamp(
        1,
        10,
      );
      return Result.success({
        'source': 'mock',
        'messages': _mockMessages.take(limit).toList(),
      });
    } catch (error) {
      return Result.failure(toToolException(error));
    }
  }
}
