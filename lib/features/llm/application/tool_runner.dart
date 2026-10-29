import 'dart:convert';

import '../../../core/error/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/tool_audit_repository.dart';
import '../domain/llm_message.dart';
import '../domain/llm_tool.dart';
import '../tools/llm_tool_registry.dart';

/// Выполняет вызовы инструментов ассистента и пишет аудит.
///
/// Ошибка инструмента не прерывает запрос: модель получает сообщение
/// `{"ok": false, "error": ...}` и может ответить пользователю. В аудит
/// попадают только имена аргументов, значения не сохраняются.
final class ToolRunner {
  ToolRunner({
    required this.registry,
    required this.audit,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LlmToolRegistry registry;
  final ToolAuditRepository audit;
  final DateTime Function() _clock;

  /// Имя неизвестного инструмента в журнале: произвольную строку от модели
  /// туда не пишем.
  static const unknownToolName = 'unknown';

  static const _maxToolNameLength = 100;

  Future<LlmMessage> run(LlmToolCall call) async {
    final tool = registry.find(call.name);
    if (tool == null) {
      await _record(unknownToolName, ToolAuditStatus.unknownTool, const []);
      return _toolMessage(call, error: 'unknown_tool');
    }

    final args = _parseArguments(call.argumentsJson);
    if (args == null) {
      await _record(tool.name, ToolAuditStatus.invalidArgs, const []);
      return _toolMessage(call, error: 'invalid_arguments');
    }
    final argumentNames = _argumentNames(tool, args);

    final Result<Map<String, Object?>> result;
    try {
      result = await tool.execute(args);
    } on Object catch (error) {
      AppLogger.w('ToolRunner: инструмент ${tool.name} упал', error);
      await _record(tool.name, ToolAuditStatus.error, argumentNames);
      return _toolMessage(call, error: 'tool_failed');
    }

    switch (result) {
      case Success<Map<String, Object?>>(:final value):
        final id = value['id'];
        await _record(
          tool.name,
          ToolAuditStatus.ok,
          argumentNames,
          entityId: id is int ? id : null,
        );
        return _toolMessage(call, data: value);
      case Failure<Map<String, Object?>>(:final error):
        await _record(tool.name, ToolAuditStatus.error, argumentNames);
        return _toolMessage(call, error: _safeMessage(error));
    }
  }

  /// Оставляет только аргументы, объявленные в схеме инструмента.
  ///
  /// Ключи приходят от модели и могут содержать произвольный (в том числе
  /// приватный) текст; в журнал попадают только имена из нашей схемы.
  static List<String> _argumentNames(LlmTool tool, Map<String, Object?> args) {
    final properties = tool.parameters['properties'];
    if (properties is! Map) return const [];
    final declared = properties.keys.whereType<String>().toSet();
    final names = [
      for (final key in args.keys)
        if (declared.contains(key)) key,
    ]..sort();
    return names;
  }

  /// null — аргументы не являются JSON-объектом.
  static Map<String, Object?>? _parseArguments(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String _safeMessage(AppException error) => switch (error) {
    ValidationException() => error.message,
    _ => 'tool_failed',
  };

  Future<void> _record(
    String toolName,
    ToolAuditStatus status,
    List<String> argumentNames, {
    int? entityId,
  }) async {
    final name = toolName.length > _maxToolNameLength
        ? toolName.substring(0, _maxToolNameLength)
        : toolName;
    final result = await audit.record(
      ToolAuditDraft(
        toolName: name,
        status: status,
        argumentNames: argumentNames,
        entityId: entityId,
        createdAt: _clock(),
      ),
    );
    result.when(success: (_) {}, failure: AppLogger.appError);
  }

  static LlmMessage _toolMessage(
    LlmToolCall call, {
    Map<String, Object?>? data,
    String? error,
  }) {
    final payload = error == null
        ? {'ok': true, 'result': data}
        : {'ok': false, 'error': error};
    return LlmMessage(
      role: LlmRole.tool,
      name: call.name,
      toolCallId: call.id,
      content: jsonEncode(payload),
    );
  }
}
