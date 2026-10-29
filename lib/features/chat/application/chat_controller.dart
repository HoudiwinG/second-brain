import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../llm/application/llm_config_controller.dart';
import '../../llm/application/llm_context_loader.dart';
import '../../llm/application/privacy_guard.dart';
import '../../llm/application/tool_runner.dart';
import '../../llm/domain/llm_chat.dart';
import '../../llm/domain/llm_endpoint.dart';
import '../../llm/domain/llm_message.dart';
import '../../llm/domain/llm_provider.dart';
import '../../llm/domain/llm_provider_config.dart';
import '../../llm/domain/llm_tool.dart';
import '../domain/chat_message.dart';
import '../domain/chat_thread.dart';
import 'chat_request_builder.dart';

const Object _unset = Object();

/// Сколько раундов вызовов инструментов допускается на один запрос.
const int maxToolRounds = 3;

/// Снимок UI-состояния чата.
final class ChatState {
  const ChatState({
    required this.threads,
    required this.messages,
    this.activeThreadId,
    this.isStreaming = false,
    this.streamingText = '',
    this.errorCode,
  });

  final List<ChatThread> threads;
  final List<ChatMessage> messages;
  final int? activeThreadId;
  final bool isStreaming;
  final String streamingText;

  /// no_config | provider_missing | api_key_missing | llm_error | cancelled.
  final String? errorCode;

  ChatThread? get activeThread {
    for (final thread in threads) {
      if (thread.id == activeThreadId) return thread;
    }
    return null;
  }

  ChatState copyWith({
    List<ChatThread>? threads,
    List<ChatMessage>? messages,
    Object? activeThreadId = _unset,
    bool? isStreaming,
    String? streamingText,
    Object? errorCode = _unset,
  }) => ChatState(
    threads: threads ?? this.threads,
    messages: messages ?? this.messages,
    activeThreadId: identical(activeThreadId, _unset)
        ? this.activeThreadId
        : activeThreadId as int?,
    isStreaming: isStreaming ?? this.isStreaming,
    streamingText: streamingText ?? this.streamingText,
    errorCode: identical(errorCode, _unset)
        ? this.errorCode
        : errorCode as String?,
  );
}

/// Контроллер чата: история, streaming, отмена и privacy guard.
///
/// Один экземпляр обслуживает ровно один активный запрос. Смена/создание/
/// удаление треда во время streaming сначала отменяют запрос, а поздние
/// колбэки старого потока игнорируются по [requestId].
final class ChatController extends AsyncNotifier<ChatState> {
  StreamSubscription<LlmChunk>? _subscription;
  Completer<void>? _activeCompleter;
  int _nextRequestId = 0;
  int? _activeRequestId;
  bool _sending = false;
  List<LlmContextRef> _lastContextRefs = const [];

  @override
  Future<ChatState> build() async {
    ref.onDispose(() {
      _activeRequestId = null;
      unawaited(_subscription?.cancel());
      final completer = _activeCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    });
    // Конфигурации нужны только для проверки наличия провайдера; чат
    // не должен пересоздаваться при каждом изменении настроек.
    await ref.read(llmConfigControllerProvider.future);
    final repo = await ref.read(chatRepositoryProvider.future);
    final threads = (await repo.listThreads()).unwrap();
    final first = threads.isEmpty ? null : threads.first;
    final messages = first == null
        ? const <ChatMessage>[]
        : (await repo.listMessages(first.id)).unwrap();
    return ChatState(
      threads: threads,
      messages: messages,
      activeThreadId: first?.id,
    );
  }

  /// Создаёт тред. Если идёт streaming, сначала отменяет его.
  Future<bool> createThread(String title) async {
    if (_sending) await cancel();
    return _createThreadInternal(title);
  }

  Future<bool> _createThreadInternal(String title) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return false;
    final config = _defaultConfig();
    if (config == null) {
      _setError('no_config');
      return false;
    }
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.createThread(
      ChatThreadDraft(
        title: normalizedTitle,
        providerConfigId: config.id,
        model: config.model,
      ),
    );
    return result.when(
      success: (thread) {
        final current = state.value;
        state = AsyncData(
          (current ?? const ChatState(threads: [], messages: [])).copyWith(
            threads: [thread, ...?current?.threads],
            messages: const [],
            activeThreadId: thread.id,
            isStreaming: false,
            streamingText: '',
            errorCode: null,
          ),
        );
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        _setError('llm_error');
        return false;
      },
    );
  }

  /// Переключает тред. Активный streaming сначала отменяется и сохраняется.
  Future<void> selectThread(int threadId) async {
    if (_sending) await cancel();
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.listMessages(threadId);
    result.when(
      success: (messages) {
        final current = state.value;
        if (current == null) return;
        state = AsyncData(
          current.copyWith(
            activeThreadId: threadId,
            messages: messages,
            isStreaming: false,
            streamingText: '',
            errorCode: null,
          ),
        );
      },
      failure: (error) {
        AppLogger.appError(error);
        _setError('llm_error');
      },
    );
  }

  Future<bool> deleteThread(int threadId) async {
    final isActive = state.value?.activeThreadId == threadId;
    if (isActive && _sending) await cancel();
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.deleteThread(threadId);
    return result.when(
      success: (_) async {
        final current = state.value;
        if (current == null) return false;
        final threads = current.threads
            .where((thread) => thread.id != threadId)
            .toList(growable: false);
        if (current.activeThreadId == threadId) {
          final first = threads.isEmpty ? null : threads.first;
          final messages = first == null
              ? const <ChatMessage>[]
              : (await repo.listMessages(first.id)).unwrap();
          state = AsyncData(
            current.copyWith(
              threads: threads,
              messages: messages,
              activeThreadId: first?.id,
              isStreaming: false,
              streamingText: '',
              errorCode: null,
            ),
          );
        } else {
          state = AsyncData(current.copyWith(threads: threads));
        }
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        _setError('llm_error');
        return false;
      },
    );
  }

  /// Отправляет сообщение и запускает streaming.
  ///
  /// Возвращает `true` сразу после принятия сообщения (оно сохранено и запрос
  /// запущен). `false` означает, что ввод не принят и UI должен его сохранить.
  /// Контекст передаётся только ссылками: флаги приватности читает
  /// [LlmContextLoader] из БД, а не вызывающий код.
  Future<bool> sendMessage(
    String text, {
    List<LlmContextRef> contextRefs = const [],
  }) async {
    final current = state.value;
    if (current == null || _sending) return false;
    final normalized = text.trim();
    if (normalized.isEmpty) return false;

    _sending = true;
    final requestId = ++_nextRequestId;
    _activeRequestId = requestId;
    _lastContextRefs = List<LlmContextRef>.unmodifiable(contextRefs);
    state = AsyncData(
      current.copyWith(isStreaming: false, streamingText: '', errorCode: null),
    );

    try {
      var thread = current.activeThread;
      if (thread == null) {
        final created = await _createThreadInternal(_titleFrom(normalized));
        if (!created || !_isActive(requestId)) return false;
        thread = state.value?.activeThread;
      }
      if (thread == null || !_isActive(requestId)) return false;
      return await _startRequest(
        requestId,
        thread,
        userText: normalized,
        contextRefs: _lastContextRefs,
      );
    } on Object catch (error, stack) {
      if (_isActive(requestId)) {
        _logError('ChatController.sendMessage', error, stack);
        _setError('llm_error');
      }
      return false;
    } finally {
      if (_activeRequestId == requestId && _activeCompleter == null) {
        _activeRequestId = null;
        _sending = false;
      }
    }
  }

  /// Повторяет последний запрос без добавления нового сообщения пользователя.
  Future<bool> retryLast() async {
    if (_sending) return false;
    final current = state.value;
    final thread = current?.activeThread;
    if (current == null || thread == null) return false;
    final hasUserMessage = current.messages.any(
      (message) =>
          message.role == LlmRole.user &&
          message.errorCode == null &&
          message.content.isNotEmpty,
    );
    if (!hasUserMessage) return false;

    _sending = true;
    final requestId = ++_nextRequestId;
    _activeRequestId = requestId;
    state = AsyncData(
      current.copyWith(isStreaming: false, streamingText: '', errorCode: null),
    );
    try {
      return await _startRequest(
        requestId,
        thread,
        contextRefs: _lastContextRefs,
      );
    } on Object catch (error, stack) {
      if (_isActive(requestId)) {
        _logError('ChatController.retryLast', error, stack);
        _setError('llm_error');
      }
      return false;
    } finally {
      if (_activeRequestId == requestId && _activeCompleter == null) {
        _activeRequestId = null;
        _sending = false;
      }
    }
  }

  Future<bool> _startRequest(
    int requestId,
    ChatThread thread, {
    String? userText,
    required List<LlmContextRef> contextRefs,
  }) async {
    final config = _configFor(thread);
    if (config == null) {
      _setError('provider_missing');
      return false;
    }
    if (!_isActive(requestId)) return false;

    final configRepo = await ref.read(llmConfigRepositoryProvider.future);
    if (!_isActive(requestId)) return false;
    final keyResult = await configRepo.readApiKey(config.id);
    if (!_isActive(requestId)) return false;

    String? apiKey;
    var keyReadFailed = false;
    keyResult.when(
      success: (value) => apiKey = value,
      failure: (error) {
        keyReadFailed = true;
        AppLogger.appError(error);
      },
    );
    if (keyReadFailed) {
      _setError('llm_error');
      return false;
    }
    if ((apiKey == null || apiKey!.isEmpty) &&
        LlmEndpoint.requiresApiKey(config.type, config.baseUrl)) {
      _setError('api_key_missing');
      return false;
    }

    final chatRepo = await ref.read(chatRepositoryProvider.future);
    if (!_isActive(requestId)) return false;
    ChatMessage? savedUser;
    if (userText != null) {
      final saved = await chatRepo.appendMessage(
        ChatMessageDraft(
          threadId: thread.id,
          role: LlmRole.user,
          content: userText,
        ),
      );
      if (!_isActive(requestId)) return false;
      savedUser = saved.when<ChatMessage?>(
        success: (message) => message,
        failure: (error) {
          AppLogger.appError(error);
          _setError('llm_error');
          return null;
        },
      );
      if (savedUser == null) return false;
    }

    final current = state.value;
    if (current == null) return false;
    final baseMessages = [...current.messages, ?savedUser];
    state = AsyncData(
      current.copyWith(
        messages: baseMessages,
        isStreaming: true,
        streamingText: '',
        errorCode: null,
      ),
    );

    final loader = await ref.read(llmContextLoaderProvider.future);
    final loadedContext = await loader.load(contextRefs);
    if (!_isActive(requestId)) return false;
    final filtered = PrivacyGuard.filter(loadedContext);
    final contextText = filtered.allowed
        .map((item) => '[${item.entityType}] ${item.title}\n${item.body}')
        .join('\n\n');
    final requestMessages = buildChatRequestMessages(
      baseMessages,
      contextText: contextText,
    );
    if (requestMessages.isEmpty) {
      _setError('llm_error');
      return false;
    }

    final registry = await ref.read(llmToolRegistryProvider.future);
    final audit = await ref.read(toolAuditRepositoryProvider.future);
    if (!_isActive(requestId)) return false;
    final runner = ToolRunner(registry: registry, audit: audit);
    final request = LlmChatRequest(
      model: _effectiveModel(thread, config),
      messages: requestMessages,
      maxTokens: config.maxTokens,
      tools: registry.definitions,
    );
    final provider = ref
        .read(llmProviderFactoryProvider)
        .create(config: config, apiKey: apiKey);

    final completer = Completer<void>();
    _activeCompleter = completer;
    await _streamRound(
      requestId: requestId,
      thread: thread,
      provider: provider,
      request: request,
      runner: runner,
      round: 0,
      completer: completer,
    );
    unawaited(_awaitRequest(requestId, completer));
    return true;
  }

  /// Один раунд streaming. Если модель запросила инструменты, после конца
  /// потока они выполняются ([_runTools]) и запускается следующий раунд с
  /// результатами. Текст раунда с вызовами не сохраняется: в историю попадает
  /// только финальный ответ.
  Future<void> _streamRound({
    required int requestId,
    required ChatThread thread,
    required LlmProvider provider,
    required LlmChatRequest request,
    required ToolRunner runner,
    required int round,
    required Completer<void> completer,
    LlmUsage? usage,
  }) async {
    final buffer = StringBuffer();
    final toolCalls = LlmToolCallAccumulator();
    var latestUsage = usage;
    if (round > 0 && _isActive(requestId)) {
      final current = state.value;
      if (current != null && current.activeThreadId == thread.id) {
        state = AsyncData(current.copyWith(streamingText: ''));
      }
    }
    try {
      _subscription = provider
          .streamChat(request)
          .listen(
            (chunk) {
              if (chunk.usage != null) latestUsage = chunk.usage;
              toolCalls.addAll(chunk.toolCallDeltas);
              if (chunk.delta.isEmpty) return;
              buffer.write(chunk.delta);
              if (!_isActive(requestId)) return;
              final currentState = state.value;
              if (currentState == null ||
                  currentState.activeThreadId != thread.id ||
                  !currentState.isStreaming) {
                return;
              }
              state = AsyncData(
                currentState.copyWith(streamingText: buffer.toString()),
              );
            },
            onError: (Object error, StackTrace stack) {
              unawaited(
                _fail(
                  thread.id,
                  requestId,
                  error,
                  stack,
                  completer,
                  buffer.toString(),
                ),
              );
            },
            onDone: () {
              final calls = toolCalls.build();
              if (calls.isEmpty) {
                unawaited(
                  _complete(
                    thread.id,
                    requestId,
                    buffer.toString(),
                    latestUsage,
                    completer,
                  ),
                );
                return;
              }
              unawaited(
                _runTools(
                  requestId: requestId,
                  thread: thread,
                  provider: provider,
                  request: request,
                  runner: runner,
                  round: round,
                  completer: completer,
                  content: buffer.toString(),
                  calls: calls,
                  usage: latestUsage,
                ),
              );
            },
            cancelOnError: true,
          );
    } on Object catch (error, stack) {
      await _fail(
        thread.id,
        requestId,
        error,
        stack,
        completer,
        buffer.toString(),
      );
    }
  }

  /// Выполняет вызовы инструментов текущего раунда и запускает следующий.
  /// Лимит раундов защищает от бесконечного цикла модели.
  Future<void> _runTools({
    required int requestId,
    required ChatThread thread,
    required LlmProvider provider,
    required LlmChatRequest request,
    required ToolRunner runner,
    required int round,
    required Completer<void> completer,
    required String content,
    required List<LlmToolCall> calls,
    LlmUsage? usage,
  }) async {
    if (completer.isCompleted) return;
    if (!_isActive(requestId)) {
      completer.complete();
      return;
    }
    if (round >= maxToolRounds) {
      await _fail(
        thread.id,
        requestId,
        const LlmException('LLM: превышен лимит вызовов инструментов'),
        StackTrace.current,
        completer,
        content,
      );
      return;
    }

    final results = <LlmMessage>[];
    for (final call in calls) {
      results.add(await runner.run(call));
      if (!_isActive(requestId)) {
        if (!completer.isCompleted) completer.complete();
        return;
      }
    }
    final next = LlmChatRequest(
      model: request.model,
      messages: [
        ...request.messages,
        LlmMessage(role: LlmRole.assistant, content: content, toolCalls: calls),
        ...results,
      ],
      maxTokens: request.maxTokens,
      temperature: request.temperature,
      tools: request.tools,
    );
    await _streamRound(
      requestId: requestId,
      thread: thread,
      provider: provider,
      request: next,
      runner: runner,
      round: round + 1,
      completer: completer,
      usage: usage,
    );
  }

  /// Останавливает текущий запрос и сохраняет уже полученный текст.
  Future<void> cancel() async {
    _activeRequestId = null;
    final subscription = _subscription;
    _subscription = null;
    // Не ждём завершения cancel(): некоторые HTTP-потоки закрываются
    // асинхронно, а UI должен остановиться сразу.
    if (subscription != null) unawaited(subscription.cancel());

    final completer = _activeCompleter;
    _activeCompleter = null;
    final current = state.value;
    if (current == null || !current.isStreaming) {
      _sending = false;
      if (completer != null && !completer.isCompleted) completer.complete();
      return;
    }

    final partial = current.streamingText;
    final threadId = current.activeThreadId;
    if (threadId != null) {
      await _saveAssistant(
        threadId,
        partial,
        null,
        errorCode: partial.isEmpty ? 'cancelled' : null,
      );
      final latest = state.value;
      if (latest != null && latest.activeThreadId == threadId) {
        state = AsyncData(
          partial.isEmpty
              ? _withError(latest, 'cancelled')
              : latest.copyWith(
                  isStreaming: false,
                  streamingText: '',
                  errorCode: null,
                ),
        );
        await _refreshMessages(threadId, force: true);
      }
    }
    _sending = false;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> _complete(
    int threadId,
    int requestId,
    String content,
    LlmUsage? usage,
    Completer<void> completer,
  ) async {
    if (completer.isCompleted) return;
    if (content.trim().isEmpty) {
      await _saveAssistant(threadId, '', null, errorCode: 'llm_error');
      if (_isActive(requestId)) {
        await _refreshMessages(threadId, requestId: requestId);
        _setError('llm_error');
      }
      if (!completer.isCompleted) completer.complete();
      return;
    }

    await _saveAssistant(threadId, content, usage);
    if (_isActive(requestId)) {
      await _refreshMessages(threadId, requestId: requestId);
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            isStreaming: false,
            streamingText: '',
            errorCode: null,
          ),
        );
      }
    }
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> _fail(
    int threadId,
    int requestId,
    Object error,
    StackTrace stack,
    Completer<void> completer,
    String partial,
  ) async {
    if (completer.isCompleted) return;
    _logError('ChatController: ошибка streaming-ответа', error, stack);
    // Partial-ответ с ошибкой тоже сохраняется, но с маркером: иначе
    // следующий запрос отправит неполный ответ как успешную историю.
    await _saveAssistant(threadId, partial, null, errorCode: 'llm_error');
    if (_isActive(requestId)) {
      await _refreshMessages(threadId, requestId: requestId);
      _setError('llm_error');
    }
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> _saveAssistant(
    int threadId,
    String content,
    LlmUsage? usage, {
    String? errorCode,
  }) async {
    if (content.isEmpty && errorCode == null) return;
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.appendMessage(
      ChatMessageDraft(
        threadId: threadId,
        role: LlmRole.assistant,
        content: content,
        promptTokens: usage?.promptTokens,
        completionTokens: usage?.completionTokens,
        errorCode: errorCode,
      ),
    );
    result.when(success: (_) {}, failure: (error) => AppLogger.appError(error));
  }

  Future<void> _refreshMessages(
    int threadId, {
    int? requestId,
    bool force = false,
  }) async {
    if (!force && requestId != null && !_isActive(requestId)) return;
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.listMessages(threadId);
    result.when(
      success: (messages) {
        final current = state.value;
        if (current == null || current.activeThreadId != threadId) return;
        if (!force && requestId != null && !_isActive(requestId)) return;
        state = AsyncData(
          current.copyWith(
            messages: messages,
            isStreaming: false,
            streamingText: '',
          ),
        );
      },
      failure: (error) => AppLogger.appError(error),
    );
  }

  Future<void> _awaitRequest(int requestId, Completer<void> completer) async {
    await completer.future;
    if (identical(_activeCompleter, completer)) _activeCompleter = null;
    if (_activeRequestId == requestId) {
      _activeRequestId = null;
      _sending = false;
      _subscription = null;
    }
  }

  /// Ждёт завершения текущего запроса (для тестов и фоновых сценариев).
  Future<void> waitForIdle() async {
    final completer = _activeCompleter;
    if (completer != null && !completer.isCompleted) await completer.future;
  }

  /// Переключает приватность сохранённого сообщения.
  Future<bool> setMessagePrivate(int messageId, bool isPrivate) async {
    final current = state.value;
    if (current == null) return false;
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.setMessagePrivate(messageId, isPrivate);
    return result.when(
      success: (_) {
        final latest = state.value;
        if (latest == null) return false;
        state = AsyncData(
          latest.copyWith(
            messages: [
              for (final message in latest.messages)
                message.id == messageId
                    ? message.copyWith(isPrivateForLlm: isPrivate)
                    : message,
            ],
          ),
        );
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        return false;
      },
    );
  }

  LlmProviderConfig? _defaultConfig() {
    final configs = ref.read(llmConfigControllerProvider).value ?? const [];
    return defaultLlmConfig(configs);
  }

  LlmProviderConfig? _configFor(ChatThread thread) {
    final configs = ref.read(llmConfigControllerProvider).value ?? const [];
    for (final config in configs) {
      if (config.id == thread.providerConfigId) return config;
    }
    return defaultLlmConfig(configs);
  }

  bool _isActive(int requestId) => _activeRequestId == requestId;

  void _setError(String code) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(_withError(current, code));
  }

  static ChatState _withError(ChatState current, String code) =>
      current.copyWith(isStreaming: false, errorCode: code);

  static String _effectiveModel(ChatThread thread, LlmProviderConfig config) =>
      config.id == thread.providerConfigId ? thread.model : config.model;

  static void _logError(String message, Object error, StackTrace stack) {
    if (error is AppException) {
      AppLogger.appError(error, stack);
    } else {
      AppLogger.e(message, error, stack);
    }
  }

  static String _titleFrom(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 57)}…';
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
