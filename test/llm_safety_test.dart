import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/error/app_exception.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/features/llm/domain/llm_endpoint.dart';
import 'package:second_brain/features/llm/domain/llm_provider_type.dart';
import 'package:second_brain/features/llm/domain/llm_tool.dart';
import 'package:second_brain/features/llm/tools/llm_tool_registry.dart';

final class _FakeTool implements LlmTool {
  _FakeTool(this.name);

  @override
  final String name;

  @override
  String get description => 'fake';

  @override
  Map<String, Object?> get parameters => const {'type': 'object'};

  @override
  LlmToolDefinition get definition => LlmToolDefinition(
    name: name,
    description: description,
    parameters: parameters,
  );

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async => const Result.success({});
}

void main() {
  test('AppException.toString не печатает cause с телом ответа', () {
    final error = LlmException(
      'Ошибка провайдера',
      cause: StateError('{"secret":"provider body"}'),
    );

    expect(error.toString(), contains('Ошибка провайдера'));
    expect(error.toString(), isNot(contains('provider body')));
    expect(error.toString(), isNot(contains('secret')));
  });

  test('реестр инструментов возвращает trim-имя в definition', () {
    final registry = LlmToolRegistry()..register(_FakeTool('  add_note  '));

    expect(registry.find('add_note'), isNotNull);
    expect(registry.definitions.single.name, 'add_note');
  });

  test('LlmEndpoint разрешает http только для loopback', () {
    expect(LlmEndpoint.isValid('https://api.example.com/v1'), isTrue);
    expect(LlmEndpoint.isValid('http://localhost:11434/v1'), isTrue);
    expect(LlmEndpoint.isValid('http://127.0.0.1:8080/v1'), isTrue);
    expect(LlmEndpoint.isValid('http://api.example.com/v1'), isFalse);
    expect(LlmEndpoint.isInsecureRemote('http://api.example.com/v1'), isTrue);
    expect(
      LlmEndpoint.requiresApiKey(
        LlmProviderType.openaiCompatible,
        'http://localhost:11434/v1',
      ),
      isFalse,
    );
    expect(
      LlmEndpoint.requiresApiKey(
        LlmProviderType.openaiCompatible,
        'https://api.example.com/v1',
      ),
      isTrue,
    );
  });
}
