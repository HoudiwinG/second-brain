import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/tool_audit_repository.dart';
import 'package:second_brain/features/llm/application/tool_runner.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';
import 'package:second_brain/features/llm/domain/llm_tool.dart';
import 'package:second_brain/features/llm/tools/built_in/create_note_tool.dart';
import 'package:second_brain/features/llm/tools/llm_tool_registry.dart';

import 'helpers/in_memory_db.dart';

void main() {
  late LlmToolRegistry registry;
  late DriftToolAuditRepository audit;
  late ToolRunner runner;

  setUp(() {
    final db = InMemoryDbFactory.open();
    registry = LlmToolRegistry()
      ..register(CreateNoteTool(DriftNotesRepository(db)));
    audit = DriftToolAuditRepository(db);
    runner = ToolRunner(
      registry: registry,
      audit: audit,
      clock: () => DateTime.utc(2026, 10, 29, 12),
    );
  });

  LlmToolCall call(String name, String argumentsJson) =>
      LlmToolCall(id: 'call_1', name: name, argumentsJson: argumentsJson);

  Map<String, Object?> payload(LlmMessage message) =>
      jsonDecode(message.content) as Map<String, Object?>;

  test('неизвестный инструмент возвращает ошибку и пишет аудит', () async {
    final message = await runner.run(call('delete_everything', '{}'));

    expect(message.role, LlmRole.tool);
    expect(message.toolCallId, 'call_1');
    expect(payload(message), {'ok': false, 'error': 'unknown_tool'});
    final recent = (await audit.listRecent()).unwrap();
    expect(recent.single.status, ToolAuditStatus.unknownTool);
    expect(
      recent.single.toolName,
      'unknown',
      reason: 'произвольное имя от модели не должно попадать в журнал',
    );
  });

  test('некорректный JSON аргументов возвращает invalid_arguments', () async {
    final message = await runner.run(call('create_note', '{не json'));

    expect(payload(message)['error'], 'invalid_arguments');
    final recent = (await audit.listRecent()).unwrap();
    expect(recent.single.status, ToolAuditStatus.invalidArgs);
  });

  test('успешный вызов создаёт сущность и пишет id без значений', () async {
    final message = await runner.run(
      call('create_note', '{"title":"Секрет дня","body":"тайный текст"}'),
    );

    final data = payload(message);
    expect(data['ok'], isTrue);
    final id = (data['result']! as Map<String, Object?>)['id'] as int;

    final recent = (await audit.listRecent()).unwrap();
    expect(recent.single.toolName, 'create_note');
    expect(recent.single.status, ToolAuditStatus.ok);
    expect(recent.single.entityId, id);
    expect(recent.single.argumentNames, ['body', 'title']);
    expect(
      recent.single.argumentNames.join(','),
      isNot(contains('тайный')),
      reason: 'аудит хранит имена аргументов, а не значения',
    );
  });

  test('в аудит попадают только объявленные в схеме аргументы', () async {
    final message = await runner.run(
      call(
        'create_note',
        '{"title":"X","Иван Петров":"секрет","body":"текст"}',
      ),
    );

    expect(payload(message)['ok'], isTrue);
    final recent = (await audit.listRecent()).unwrap();
    expect(recent.single.argumentNames, ['body', 'title']);
    expect(
      recent.single.argumentNames.join(','),
      isNot(contains('Иван')),
      reason: 'неизвестные ключи от модели не пишутся в журнал',
    );
  });

  test('ошибка валидации уходит модели текстом без значений', () async {
    final message = await runner.run(
      call('create_note', '{"title":"   ","body":"значение"}'),
    );

    final data = payload(message);
    expect(data['ok'], isFalse);
    expect(data['error'], contains('title'));
    final recent = (await audit.listRecent()).unwrap();
    expect(recent.single.status, ToolAuditStatus.error);
  });
}
