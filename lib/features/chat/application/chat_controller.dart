import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../llm/application/llm_config_controller.dart';
import '../../llm/application/privacy_guard.dart';
import '../../llm/domain/llm_chat.dart';
import '../../llm/domain/llm_message.dart';
import '../../llm/domain/llm_provider_config.dart';
import '../domain/chat_message.dart';
import '../domain/chat_thread.dart';

const Object _unset = Object();

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

  /// no_config | provider_missing | llm_error | cancelled.
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
final class ChatController extends AsyncNotifier<ChatState> {
  StreamSubscription<LlmChunk>? _subscription;
  Completer<void>? _activeCompleter;

  @override
  Future<ChatState> build() async {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _activeCompleter?.complete();
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

  Future<bool> createThread(String title) async {
    final config = _defaultConfig();
    if (config == null) {
      _setError('no_config');
      return false;
    }
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.createThread(
      ChatThreadDraft(
        title: title.trim().isEmpty ? 'Chat' : title.trim(),
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

  Future<void> selectThread(int threadId) async {
    if (_subscription != null) await cancel();
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
    if (state.value?.activeThreadId == threadId) await cancel();
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

  /// Отправляет сообщение и стримит ответ.
  ///
  /// [context] проходит через [PrivacyGuard] до формирования запроса.
  Future<void> sendMessage(
    String text, {
    List<LlmContextItem> context = const [],
  }) async {
    final current = state.value;
    if (current == null || current.isStreaming) return;
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    var thread = current.activeThread;
    if (thread == null) {
      final created = await createThread(_titleFrom(normalized));
      if (!created) return;
      thread = state.value?.activeThread;
    }
    if (thread == null) return;

    final config = _configFor(thread);
    if (config == null) {
      _setError('provider_missing');
      return;
    }

    final configRepo = await ref.read(llmConfigRepositoryProvider.future);
    final keyResult = await configRepo.readApiKey(config.id);
    final key = keyResult.when<String?>(
      success: (value) => value,
      failure: (error) {
        AppLogger.appError(error);
        _setError('llm_error');
        return null;
      },
    );
    if (state.value?.errorCode == 'llm_error') return;

    final chatRepo = await ref.read(chatRepositoryProvider.future);
    final savedUser = await chatRepo.appendMessage(
      ChatMessageDraft(
        threadId: thread.id,
        role: LlmRole.user,
        content: normalized,
      ),
    );
    final userMessage = savedUser.when<ChatMessage?>(
      success: (message) => message,
      failure: (error) {
        AppLogger.appError(error);
        _setError('llm_error');
        return null;
      },
    );
    if (userMessage == null) return;

    final baseMessages = [...?state.value?.messages, userMessage];
    state = AsyncData(
      (state.value ?? current).copyWith(
        messages: baseMessages,
        isStreaming: true,
        streamingText: '',
        errorCode: null,
      ),
    );

    final filtered = PrivacyGuard.filter(context);
    final contextText = filtered.allowed
        .map((item) => '[${item.entityType}] ${item.title}\n${item.body}')
        .join('\n\n');
    final requestMessages = _toRequestMessages(baseMessages, contextText);
    final tools = ref.read(llmToolRegistryProvider).definitions;
    final request = LlmChatRequest(
      model: thread.model,
      messages: requestMessages,
      maxTokens: config.maxTokens,
      tools: tools,
    );

    final provider = ref.read(llmProviderFactoryProvider).create(
      config: config,
      apiKey: key,
    );
    final buffer = StringBuffer();
    LlmUsage? usage;
    final completer = Completer<void>();
    _activeCompleter = completer;

    try {
      _subscription = provider
          .streamChat(request)
          .listen(
            (chunk) {
              if (chunk.usage != null) usage = chunk.usage;
              if (chunk.delta.isEmpty) return;
              buffer.write(chunk.delta);
              final currentState = state.value;
              if (currentState == null) return;
              state = AsyncData(
                currentState.copyWith(streamingText: buffer.toString()),
              );
            },
            onError: (Object error, StackTrace stack) {
              unawaited(
                _fail(thread!.id, error, stack, completer, buffer.toString()),
              );
            },
            onDone: () {
              unawaited(
                _complete(
                  thread!.id,
                  buffer.toString(),
                  usage,
                  completer,
                ),
              );
            },
            cancelOnError: true,
          );
    } on Object catch (error, stack) {
      await _fail(thread.id, error, stack, completer, '');
      return;
    }
    await completer.future;
    _subscription = null;
    if (identical(_activeCompleter, completer)) _activeCompleter = null;
  }

  /// Останавливает текущий запрос и сохраняет уже полученный текст.
  Future<void> cancel() async {
    final subscription = _subscription;
    _subscription = null;
    // Не ждём завершения cancel(): некоторые HTTP-потоки закрываются
    // асинхронно, а UI должен остановиться сразу.
    if (subscription != null) unawaited(subscription.cancel());

    final current = state.value;
    final completer = _activeCompleter;
    _activeCompleter = null;
    if (current == null || !current.isStreaming) {
      completer?.complete();
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
      state = AsyncData(
        partial.isEmpty
            ? _withError(current, 'cancelled')
            : current.copyWith(
                isStreaming: false,
                streamingText: '',
                errorCode: null,
              ),
      );
      await _refreshMessages(threadId);
    }
    completer?.complete();
  }

  Future<void> _complete(
    int threadId,
    String content,
    LlmUsage? usage,
    Completer<void> completer,
  ) async {
    if (completer.isCompleted) return;
    if (content.trim().isEmpty) {
      await _saveAssistant(threadId, '', null, errorCode: 'llm_error');
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            isStreaming: false,
            streamingText: '',
            errorCode: 'llm_error',
          ),
        );
      }
      await _refreshMessages(threadId);
      completer.complete();
      return;
    }

    await _saveAssistant(threadId, content, usage);
    await _refreshMessages(threadId);
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
    completer.complete();
  }

  Future<void> _fail(
    int threadId,
    Object error,
    StackTrace stack,
    Completer<void> completer,
    String partial,
  ) async {
    if (completer.isCompleted) return;
    if (error is AppException) {
      AppLogger.appError(error, stack);
    } else {
      AppLogger.e('ChatController: ошибка streaming-ответа', error, stack);
    }
    await _saveAssistant(
      threadId,
      partial,
      null,
      errorCode: partial.isEmpty ? 'llm_error' : null,
    );
    await _refreshMessages(threadId);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          isStreaming: false,
          streamingText: '',
          errorCode: partial.isEmpty ? 'llm_error' : null,
        ),
      );
    }
    completer.complete();
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
    result.when(
      success: (_) {},
      failure: (error) => AppLogger.appError(error),
    );
  }

  Future<void> _refreshMessages(int threadId) async {
    final repo = await ref.read(chatRepositoryProvider.future);
    final result = await repo.listMessages(threadId);
    result.when(
      success: (messages) {
        final current = state.value;
        if (current == null) return;
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

  void _setError(String code) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(_withError(current, code));
  }

  static ChatState _withError(ChatState current, String code) =>
      current.copyWith(isStreaming: false, errorCode: code);

  static String _titleFrom(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 57)}…';
  }

  /// Ограничивает историю, чтобы не отправить в LLM весь архив.
  static List<LlmMessage> _toRequestMessages(
    List<ChatMessage> history,
    String contextText,
  ) {
    final usable = history
        .where((message) => message.errorCode == null && message.content.isNotEmpty)
        .toList(growable: false);
    final tail = usable.length > 40
        ? usable.sublist(usable.length - 40)
        : usable;
    var totalChars = 0;
    final selected = <ChatMessage>[];
    for (final message in tail.reversed) {
      if (totalChars + message.content.length > 60000 && selected.isNotEmpty) {
        break;
      }
      selected.add(message);
      totalChars += message.content.length;
    }
    final ordered = selected.reversed.toList(growable: false);
    return [
      for (final message in ordered)
        LlmMessage(
          role: message.role,
          content: message == ordered.last && contextText.isNotEmpty
              ? '${message.content}\n\n[context]\n$contextText'
              : message.content,
        ),
    ];
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
