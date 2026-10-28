import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/chat/application/chat_request_builder.dart';
import 'package:second_brain/features/chat/domain/chat_message.dart';
import 'package:second_brain/features/llm/domain/llm_message.dart';

ChatMessage _message(
  int id,
  LlmRole role,
  String content, {
  bool isPrivate = false,
  String? errorCode,
}) => ChatMessage(
  id: id,
  threadId: 1,
  role: role,
  content: content,
  promptTokens: null,
  completionTokens: null,
  errorCode: errorCode,
  isPrivateForLlm: isPrivate,
  createdAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: id)),
);

void main() {
  test('оставляет последние 40 сообщений и не начинает с assistant', () {
    final history = [
      for (var i = 0; i < 45; i++)
        _message(i, i.isEven ? LlmRole.user : LlmRole.assistant, 'm$i'),
    ];

    final request = buildChatRequestMessages(history);

    expect(request, hasLength(39));
    expect(request.first.role, LlmRole.user);
    expect(request.last.role, LlmRole.user);
    expect(request.first.content, 'm6');
  });

  test('склеивает подряд идущие сообщения одной роли', () {
    final request = buildChatRequestMessages([
      _message(1, LlmRole.user, 'first'),
      _message(2, LlmRole.user, 'second'),
      _message(3, LlmRole.assistant, 'answer'),
    ]);

    expect(request, hasLength(2));
    expect(request.first.role, LlmRole.user);
    expect(request.first.content, 'first\n\nsecond');
    expect(request.last.role, LlmRole.assistant);
  });

  test('исключает приватные сообщения и маркеры ошибок', () {
    final request = buildChatRequestMessages([
      _message(1, LlmRole.user, 'private', isPrivate: true),
      _message(2, LlmRole.user, 'failed', errorCode: 'llm_error'),
      _message(3, LlmRole.user, 'ok'),
    ]);

    expect(request, hasLength(1));
    expect(request.single.content, 'ok');
  });

  test('не превышает 60 000 символов одним длинным сообщением', () {
    final request = buildChatRequestMessages([
      _message(1, LlmRole.user, 'x' * 70000),
    ]);

    expect(request, hasLength(1));
    expect(request.single.content.length, maxHistoryChars);
  });

  test('контекст добавляется к последнему user-сообщению', () {
    final request = buildChatRequestMessages([
      _message(1, LlmRole.user, 'question'),
      _message(2, LlmRole.assistant, 'answer'),
    ], contextText: 'context body');

    expect(request, hasLength(2));
    expect(request.first.content, contains('question'));
    expect(request.first.content, contains('context body'));
    expect(request.last.content, 'answer');
  });

  test('контекст учитывается в общем лимите символов', () {
    final request = buildChatRequestMessages([
      _message(1, LlmRole.user, 'q' * 59000),
    ], contextText: 'c' * 5000);

    final total = request.fold<int>(
      0,
      (sum, item) => sum + item.content.length,
    );
    expect(total, lessThanOrEqualTo(maxHistoryChars));
  });
}
