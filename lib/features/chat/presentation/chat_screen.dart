import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../llm/application/llm_config_controller.dart';
import '../../llm/domain/llm_message.dart';
import '../../llm/domain/llm_provider_config.dart';
import '../application/chat_controller.dart';
import '../domain/chat_message.dart';

/// Экран AI-чата: streaming, отмена, история и переключение моделей.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final accepted = await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(text);
    if (!mounted) return;
    // Поле очищается только после подтверждения приёма: при ошибке
    // конфигурации/ключа текст остаётся у пользователя.
    if (accepted) _input.clear();
    _scrollToBottom();
  }

  Future<void> _retry() async {
    await ref.read(chatControllerProvider.notifier).retryLast();
    _scrollToBottom();
  }

  Future<void> _newThread(AppLocalizations lcm) async {
    final ok = await ref
        .read(chatControllerProvider.notifier)
        .createThread(lcm.chatNewThread);
    if (!ok && mounted) {
      showMessageSnackBar(context, lcm.chatConfigMissing);
    }
    _scrollToBottom();
  }

  Future<void> _deleteThread(AppLocalizations lcm) async {
    final state = ref.read(chatControllerProvider).value;
    final thread = state?.activeThread;
    if (thread == null) return;
    final confirmed = await confirmDelete(context, lcm);
    if (!confirmed) return;
    final ok = await ref
        .read(chatControllerProvider.notifier)
        .deleteThread(thread.id);
    if (!mounted) return;
    showMessageSnackBar(context, ok ? lcm.chatThreadDeleted : lcm.chatError);
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final configs = ref.watch(llmConfigControllerProvider);
    final chat = ref.watch(chatControllerProvider);

    ref.listen<AsyncValue<ChatState>>(chatControllerProvider, (previous, next) {
      if (next.hasValue) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.chatTitle),
        actions: [
          IconButton(
            tooltip: lcm.chatNewThread,
            onPressed: () => _newThread(lcm),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: configs.hasError
          ? ErrorState(
              message: lcm.errorUnexpected,
              retryLabel: lcm.retryAction,
              onRetry: () => ref.invalidate(llmConfigControllerProvider),
            )
          : chat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorState(
                message: lcm.errorUnexpected,
                retryLabel: lcm.retryAction,
                onRetry: () => ref.invalidate(chatControllerProvider),
              ),
              data: (state) => _ChatBody(
                state: state,
                configs: configs.value ?? const [],
                input: _input,
                scroll: _scroll,
                onSend: _send,
                onStop: () =>
                    ref.read(chatControllerProvider.notifier).cancel(),
                onNewThread: () => _newThread(lcm),
                onDeleteThread: () => _deleteThread(lcm),
                onOpenSettings: () => context.go('/settings'),
                onRetry: _retry,
                onTogglePrivacy: (messageId, isPrivate) {
                  ref
                      .read(chatControllerProvider.notifier)
                      .setMessagePrivate(messageId, isPrivate);
                },
              ),
            ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.configs,
    required this.input,
    required this.scroll,
    required this.onSend,
    required this.onStop,
    required this.onNewThread,
    required this.onDeleteThread,
    required this.onOpenSettings,
    required this.onRetry,
    required this.onTogglePrivacy,
  });

  final ChatState state;
  final List<LlmProviderConfig> configs;
  final TextEditingController input;
  final ScrollController scroll;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onNewThread;
  final VoidCallback onDeleteThread;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  final void Function(int messageId, bool isPrivate) onTogglePrivacy;

  LlmProviderConfig? get _activeConfig {
    final id = state.activeThread?.providerConfigId;
    for (final config in configs) {
      if (config.id == id) return config;
    }
    return defaultLlmConfig(configs);
  }

  String? get _modelLabel {
    final config = _activeConfig;
    if (config == null) return null;
    final thread = state.activeThread;
    return config.id == thread?.providerConfigId ? thread!.model : config.model;
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final hasConfigs = configs.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasConfigs)
          _ConfigBanner(
            message: lcm.chatNoConfig,
            actionLabel: lcm.chatOpenSettings,
            onOpenSettings: onOpenSettings,
          ),
        _ThreadBar(
          state: state,
          config: _activeConfig,
          modelLabel: _modelLabel,
          onSelect: (id) =>
              ProviderScope.containerOf(context)
                  .read(chatControllerProvider.notifier)
                  .selectThread(id),
          onNewThread: onNewThread,
          onDelete: onDeleteThread,
        ),
        const Divider(height: 1),
        Expanded(
          child: _MessagesView(
            state: state,
            scroll: scroll,
            onTogglePrivacy: onTogglePrivacy,
          ),
        ),
        if (state.errorCode != null)
          _ErrorBanner(
            code: state.errorCode!,
            onOpenSettings: onOpenSettings,
            onRetry: onRetry,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            lcm.chatPrivacyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _Composer(
          controller: input,
          isStreaming: state.isStreaming,
          enabled: hasConfigs,
          onSend: onSend,
          onStop: onStop,
        ),
      ],
    );
  }
}

class _ConfigBanner extends StatelessWidget {
  const _ConfigBanner({
    required this.message,
    required this.actionLabel,
    required this.onOpenSettings,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.key_outlined, color: colors.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(onPressed: onOpenSettings, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ThreadBar extends StatelessWidget {
  const _ThreadBar({
    required this.state,
    required this.config,
    required this.modelLabel,
    required this.onSelect,
    required this.onNewThread,
    required this.onDelete,
  });

  final ChatState state;
  final LlmProviderConfig? config;
  final String? modelLabel;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewThread;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final threads = state.threads;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: threads.isEmpty
                ? Text(
                    lcm.chatNoThreads,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : DropdownButton<int>(
                    isExpanded: true,
                    value: state.activeThreadId,
                    hint: Text(lcm.chatThreadLabel),
                    items: [
                      for (final thread in threads)
                        DropdownMenuItem(
                          value: thread.id,
                          child: Text(
                            thread.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) onSelect(id);
                    },
                  ),
          ),
          if (config != null && modelLabel != null) ...[
            const SizedBox(width: 12),
            Text(
              lcm.chatModelParams(modelLabel!, config!.maxTokens),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          IconButton(
            tooltip: lcm.chatNewThread,
            onPressed: onNewThread,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          if (threads.isNotEmpty)
            IconButton(
              tooltip: lcm.chatDeleteThread,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _MessagesView extends StatelessWidget {
  const _MessagesView({
    required this.state,
    required this.scroll,
    required this.onTogglePrivacy,
  });

  final ChatState state;
  final ScrollController scroll;
  final void Function(int messageId, bool isPrivate) onTogglePrivacy;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final showStreaming = state.isStreaming;
    final count = state.messages.length + (showStreaming ? 1 : 0);
    if (count == 0) {
      return EmptyListState(icon: Icons.forum_outlined, message: lcm.chatEmpty);
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) {
        if (showStreaming && index == state.messages.length) {
          return _MessageBubble(
            role: LlmRole.assistant,
            content: state.streamingText,
            streaming: true,
          );
        }
        final message = state.messages[index];
        return _MessageBubble.forMessage(
          message,
          onTogglePrivacy: () =>
              onTogglePrivacy(message.id, !message.isPrivateForLlm),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.role,
    required this.content,
    this.streaming = false,
    this.errorCode,
    this.isPrivateForLlm = false,
    this.onTogglePrivacy,
  });

  factory _MessageBubble.forMessage(
    ChatMessage message, {
    required VoidCallback onTogglePrivacy,
  }) => _MessageBubble(
    role: message.role,
    content: message.content,
    errorCode: message.errorCode,
    isPrivateForLlm: message.isPrivateForLlm,
    onTogglePrivacy: onTogglePrivacy,
  );

  final LlmRole role;
  final String content;
  final bool streaming;
  final String? errorCode;
  final bool isPrivateForLlm;
  final VoidCallback? onTogglePrivacy;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final isUser = role == LlmRole.user;
    final theme = Theme.of(context);
    final errorText = switch (errorCode) {
      'cancelled' => lcm.chatCancelled,
      null => null,
      _ => lcm.chatError,
    };
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? lcm.chatYou : lcm.chatAssistant,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            if (content.isEmpty && streaming)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (content.isNotEmpty)
              SelectableText(content),
            if (errorText != null) ...[
              if (content.isNotEmpty) const SizedBox(height: 6),
              Text(errorText, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (streaming) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (onTogglePrivacy != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPrivateForLlm)
                    Text(
                      lcm.chatPrivateMessage,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isPrivateForLlm
                        ? lcm.chatUnmarkPrivate
                        : lcm.chatMarkPrivate,
                    onPressed: onTogglePrivacy,
                    icon: Icon(
                      isPrivateForLlm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.code,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final String code;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final text = switch (code) {
      'no_config' => lcm.chatNoConfig,
      'provider_missing' => lcm.chatProviderMissing,
      'api_key_missing' => lcm.chatApiKeyMissing,
      'cancelled' => lcm.chatCancelled,
      _ => lcm.chatError,
    };
    final configError =
        code == 'no_config' ||
        code == 'provider_missing' ||
        code == 'api_key_missing';
    final canRetry = code == 'llm_error';
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
            if (configError)
              TextButton(
                onPressed: onOpenSettings,
                child: Text(lcm.chatOpenSettings),
              ),
            if (canRetry)
              TextButton(onPressed: onRetry, child: Text(lcm.chatRetry)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isStreaming,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isStreaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final canSend = enabled || isStreaming;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled || isStreaming,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (!isStreaming && enabled) onSend();
              },
              decoration: dataFieldDecoration(
                enabled ? lcm.chatInputHint : lcm.chatNoConfig,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: isStreaming ? lcm.chatStop : lcm.chatSend,
            onPressed: canSend ? (isStreaming ? onStop : onSend) : null,
            icon: Icon(isStreaming ? Icons.stop : Icons.send),
          ),
        ],
      ),
    );
  }
}
