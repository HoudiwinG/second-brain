import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../domain/llm_tool.dart';

/// Инструмент, доступный LLM.
///
/// Stage-03 содержит только контракт и реестр; фактические инструменты
/// (заметки, задачи, финансы) добавляются на stage-04 с аудитом действий.
abstract interface class LlmTool {
  String get name;

  String get description;

  Map<String, Object?> get parameters;

  Future<Result<Map<String, Object?>>> execute(Map<String, Object?> arguments);

  LlmToolDefinition get definition => LlmToolDefinition(
    // Реестр ищет по trim(), поэтому провайдер должен получить то же имя.
    name: name.trim(),
    description: description,
    parameters: parameters,
  );
}

/// Реестр инструментов с защитой от дубликатов имён.
final class LlmToolRegistry {
  final Map<String, LlmTool> _tools = {};

  /// Регистрирует инструмент. Дубликат — ошибка конфигурации.
  void register(LlmTool tool) {
    final name = tool.name.trim();
    if (name.isEmpty) {
      throw const ValidationException(
        'LlmToolRegistry: пустое имя инструмента',
      );
    }
    if (_tools.containsKey(name)) {
      throw ValidationException(
        'LlmToolRegistry: инструмент "$name" уже зарегистрирован',
      );
    }
    _tools[name] = tool;
  }

  LlmTool? find(String name) => _tools[name];

  List<LlmToolDefinition> get definitions => [
    for (final tool in _tools.values)
      LlmToolDefinition(
        name: tool.name.trim(),
        description: tool.description,
        parameters: tool.parameters,
      ),
  ];

  int get length => _tools.length;
}
