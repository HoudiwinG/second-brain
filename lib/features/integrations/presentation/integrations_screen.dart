import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../core/result/result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../mail/application/mail_oauth.dart';
import '../../mail/domain/mail_account.dart';
import '../../mail/domain/mail_message.dart';
import '../../mail/domain/mail_provider_type.dart';
import '../../tasks/domain/task_item.dart';

/// Экран интеграций: почтовые аккаунты, письма, суммаризация и задачи.
class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  final _searchController = TextEditingController();
  Future<_MailData>? _future;
  Timer? _searchDebounce;
  int? _selectedAccountId;
  String _query = '';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<_MailData> _load() async {
    final repo = await ref.read(mailRepositoryProvider.future);
    final accounts = (await repo.listAccounts()).unwrap();
    final selected =
        _selectedAccountId ?? (accounts.isEmpty ? null : accounts.first.id);
    final messages = selected == null
        ? const <MailMessage>[]
        : (await repo.listMessages(
            accountId: selected,
            query: _query,
            limit: 100,
          )).unwrap();
    return _MailData(
      accounts: accounts,
      selectedAccountId: selected,
      messages: messages,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _connect() async {
    final lcm = AppLocalizations.of(context)!;
    final input = await showDialog<_MailConnectInput>(
      context: context,
      builder: (_) => const _MailAccountDialog(),
    );
    if (input == null || !mounted) return;
    final draft = input.draft;
    final oauth = ref.read(mailOAuthServiceProvider);
    final result = await oauth.connect(
      draft.provider,
      clientId: draft.clientId,
      clientSecret: input.clientSecret,
      loginHint: draft.email,
    );
    if (!mounted) return;
    if (result is Failure<MailTokens>) {
      showMessageSnackBar(context, lcm.mailOAuthError);
      return;
    }
    final tokens = (result as Success<MailTokens>).value;
    final repo = await ref.read(mailRepositoryProvider.future);
    final accounts = (await repo.listAccounts()).unwrap();
    MailAccount? existing;
    for (final account in accounts) {
      if (account.provider == draft.provider &&
          account.email.toLowerCase() == draft.email.trim().toLowerCase()) {
        existing = account;
        break;
      }
    }
    if (existing != null) {
      final stored = await oauth.storeTokens(existing.secretRef, tokens);
      if (!mounted) return;
      if (stored is Failure<void>) {
        showMessageSnackBar(context, lcm.mailAccountAddError);
        return;
      }
      final updated = await repo.updateAccount(
        existing.id,
        clientId: draft.clientId,
      );
      if (!mounted) return;
      if (updated is Failure<MailAccount>) {
        showMessageSnackBar(context, lcm.mailAccountAddError);
        return;
      }
      _selectedAccountId = existing.id;
      _reload();
      showMessageSnackBar(context, lcm.mailAccountAdded);
      return;
    }
    final created = await repo.createAccount(draft);
    if (!mounted) return;
    if (created is Failure<MailAccount>) {
      showMessageSnackBar(context, lcm.mailAccountAddError);
      return;
    }
    final account = (created as Success<MailAccount>).value;
    final stored = await oauth.storeTokens(account.secretRef, tokens);
    if (stored is Failure<void>) {
      await repo.deleteAccount(account.id);
      if (!mounted) return;
      showMessageSnackBar(context, lcm.mailAccountAddError);
      return;
    }
    if (!mounted) return;
    _selectedAccountId = account.id;
    _reload();
    showMessageSnackBar(context, lcm.mailAccountAdded);
  }

  Future<void> _reconnect(MailAccount account) async {
    final lcm = AppLocalizations.of(context)!;
    final input = await showDialog<_MailConnectInput>(
      context: context,
      builder: (_) => _MailAccountDialog(initialAccount: account),
    );
    if (input == null || !mounted) return;
    final oauth = ref.read(mailOAuthServiceProvider);
    final result = await oauth.connect(
      account.provider,
      clientId: input.draft.clientId,
      clientSecret: input.clientSecret,
      loginHint: account.email,
    );
    if (!mounted) return;
    if (result is Failure<MailTokens>) {
      showMessageSnackBar(context, lcm.mailOAuthError);
      return;
    }
    final stored = await oauth.storeTokens(
      account.secretRef,
      (result as Success<MailTokens>).value,
    );
    if (!mounted) return;
    if (stored is Failure<void>) {
      showMessageSnackBar(context, lcm.mailAccountAddError);
      return;
    }
    final repo = await ref.read(mailRepositoryProvider.future);
    final updated = await repo.updateAccount(
      account.id,
      clientId: input.draft.clientId,
      displayName: input.draft.displayName,
      isPrivateForLlm: input.draft.isPrivateForLlm,
    );
    if (!mounted) return;
    if (updated is Failure<MailAccount>) {
      showMessageSnackBar(context, lcm.mailAccountAddError);
      return;
    }
    _reload();
    showMessageSnackBar(context, lcm.mailAccountAdded);
  }

  Future<void> _sync(MailAccount account) async {
    final lcm = AppLocalizations.of(context)!;
    setState(() => _syncing = true);
    try {
      final service = await ref.read(mailSyncServiceProvider.future);
      final result = await service.sync(account);
      if (!mounted) return;
      result.when(
        success: (count) {
          _reload();
          showMessageSnackBar(context, lcm.mailSyncDone(count));
        },
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Object {
      if (mounted) showMessageSnackBar(context, lcm.mailSyncError);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _deleteAccount(MailAccount account) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(mailRepositoryProvider.future);
    final result = await repo.deleteAccount(account.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        if (_selectedAccountId == account.id) _selectedAccountId = null;
        _reload();
        showMessageSnackBar(context, lcm.mailAccountDeleted);
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _togglePrivate(MailAccount account, bool value) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(mailRepositoryProvider.future);
    final result = await repo.updateAccount(account.id, isPrivateForLlm: value);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _setMessagePrivate(MailMessage message, bool value) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(mailRepositoryProvider.future);
    final result = await repo.updateMessagePrivacy(message.id, value);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _summarize(MailMessage message) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(mailRepositoryProvider.future);
    final fresh = await repo.getMessage(message.id);
    if (!mounted) return;
    if (fresh is Failure<MailMessage?>) {
      showErrorSnackBar(context, lcm, fresh.error);
      return;
    }
    final actual = (fresh as Success<MailMessage?>).value;
    if (actual == null) {
      showMessageSnackBar(context, lcm.mailSummarizeError);
      return;
    }
    final service = await ref.read(mailSummaryServiceProvider.future);
    final result = await service.summarizeMessage(actual);
    if (!mounted) return;
    result.when(
      success: (text) => _showText(lcm.mailSummary, text),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _createTask(MailMessage message) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(tasksRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.create(
      TaskDraft(
        title: message.displayTitle.isEmpty
            ? lcm.mailNoSubject
            : message.displayTitle,
        // Тело письма не копируем: задача не должна «пережить» включение
        // приватности ящика и утечь в LLM вместе с текстом переписки.
        description:
            '${lcm.mailFrom}: ${message.fromAddress}\n'
            '${lcm.mailReceived}: ${formatDateTime(context, message.receivedAt)}',
        // Задача из почты всегда private: даже если ящик станет приватным
        // позже, задача не должна уйти в LLM с фрагментом переписки.
        isPrivateForLlm: true,
      ),
    );
    if (!mounted) return;
    result.when(
      success: (_) => showMessageSnackBar(context, lcm.mailTaskCreated),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  void _showText(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.actionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessage(MailMessage message) async {
    final lcm = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          message.displayTitle.isEmpty
              ? lcm.mailNoSubject
              : message.displayTitle,
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lcm.mailFrom}: ${message.fromAddress}'),
                Text(
                  '${lcm.mailReceived}: '
                  '${formatDateTime(context, message.receivedAt)}',
                ),
                const Divider(),
                SelectableText(
                  message.body.isEmpty ? message.snippet : message.body,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lcm.mailPrivate),
                  value: message.isPrivateForLlm,
                  onChanged: (value) {
                    Navigator.of(dialogContext).pop();
                    _setMessagePrivate(message, value);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: message.isPrivateForLlm
                ? null
                : () {
                    Navigator.of(dialogContext).pop();
                    _summarize(message);
                  },
            child: Text(lcm.mailSummary),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _createTask(message);
            },
            child: Text(lcm.mailCreateTask),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(lcm.actionClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.navIntegrations),
        actions: [
          IconButton(
            tooltip: lcm.mailAddAccount,
            onPressed: _connect,
            icon: const Icon(Icons.add_link_outlined),
          ),
          IconButton(
            tooltip: lcm.actionRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: dataFieldDecoration(lcm.mailSearchHint),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  _query = value;
                  _reload();
                });
              },
              onSubmitted: (value) {
                _searchDebounce?.cancel();
                _query = value;
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<_MailData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return ErrorState(
                    message: lcm.errorUnexpected,
                    retryLabel: lcm.retryAction,
                    onRetry: _reload,
                  );
                }
                final data = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _MailHeader(lcm: lcm),
                    const SizedBox(height: 12),
                    if (data.accounts.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(lcm.mailNoAccounts),
                          trailing: FilledButton(
                            onPressed: _connect,
                            child: Text(lcm.mailAddAccount),
                          ),
                        ),
                      )
                    else
                      for (final account in data.accounts) ...[
                        _AccountCard(
                          account: account,
                          syncing: _syncing,
                          selected: account.id == data.selectedAccountId,
                          onSelect: () {
                            _selectedAccountId = account.id;
                            _reload();
                          },
                          onSync: () => _sync(account),
                          onReconnect: () => _reconnect(account),
                          onDelete: () => _deleteAccount(account),
                          onPrivate: (value) => _togglePrivate(account, value),
                        ),
                        const SizedBox(height: 8),
                      ],
                    if (data.accounts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lcm.mailMessages,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (data.selectedAccountId != null)
                            Text(
                              '${data.messages.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      if (data.messages.isEmpty)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.inbox_outlined),
                            title: Text(lcm.mailNoMessages),
                          ),
                        )
                      else
                        for (final message in data.messages)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                message.isPrivateForLlm
                                    ? Icons.visibility_off_outlined
                                    : Icons.mail_outline,
                              ),
                              title: Text(
                                message.displayTitle.isEmpty
                                    ? lcm.mailNoSubject
                                    : message.displayTitle,
                              ),
                              subtitle: Text(
                                '${message.fromAddress}\n${message.snippet}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                formatDate(context, message.receivedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap: () => _openMessage(message),
                            ),
                          ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MailData {
  const _MailData({
    required this.accounts,
    required this.selectedAccountId,
    required this.messages,
  });

  final List<MailAccount> accounts;
  final int? selectedAccountId;
  final List<MailMessage> messages;
}

class _MailHeader extends StatelessWidget {
  const _MailHeader({required this.lcm});

  final AppLocalizations lcm;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lcm.mailSection, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(lcm.mailHint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.syncing,
    required this.selected,
    required this.onSelect,
    required this.onSync,
    required this.onReconnect,
    required this.onDelete,
    required this.onPrivate,
  });

  final MailAccount account;
  final bool syncing;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onSync;
  final VoidCallback onReconnect;
  final VoidCallback onDelete;
  final ValueChanged<bool> onPrivate;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onSelect,
        leading: const Icon(Icons.alternate_email),
        title: Text(
          account.displayName.isEmpty ? account.email : account.displayName,
        ),
        subtitle: Text('${account.provider.label} · ${account.email}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: lcm.mailPrivate,
              onPressed: () => onPrivate(!account.isPrivateForLlm),
              icon: Icon(
                account.isPrivateForLlm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            IconButton(
              tooltip: lcm.mailReconnect,
              onPressed: onReconnect,
              icon: const Icon(Icons.login),
            ),
            IconButton(
              tooltip: lcm.mailSync,
              onPressed: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
            IconButton(
              tooltip: lcm.mailDeleteAccount,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailAccountDialog extends StatefulWidget {
  const _MailAccountDialog({this.initialAccount});

  final MailAccount? initialAccount;

  @override
  State<_MailAccountDialog> createState() => _MailAccountDialogState();
}

class _MailConnectInput {
  const _MailConnectInput({required this.draft, this.clientSecret});

  final MailAccountDraft draft;
  final String? clientSecret;
}

class _MailAccountDialogState extends State<_MailAccountDialog> {
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  MailProviderType _provider = MailProviderType.gmail;
  bool _private = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    if (account != null) {
      _provider = account.provider;
      _private = account.isPrivateForLlm;
      _email.text = account.email;
      _displayName.text = account.displayName;
      _clientId.text = account.clientId;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  void _submit() {
    final lcm = AppLocalizations.of(context)!;
    if (!_email.text.contains('@') || _clientId.text.trim().isEmpty) {
      setState(() => _error = lcm.mailOAuthMissing);
      return;
    }
    Navigator.of(context).pop(
      _MailConnectInput(
        draft: MailAccountDraft(
          provider: _provider,
          email: _email.text,
          displayName: _displayName.text,
          clientId: _clientId.text,
          isPrivateForLlm: _private,
        ),
        clientSecret: _clientSecret.text.trim().isEmpty
            ? null
            : _clientSecret.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.mailAddAccount),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<MailProviderType>(
                initialValue: _provider,
                decoration: dataFieldDecoration(lcm.mailProvider),
                items: [
                  for (final provider in MailProviderType.values)
                    DropdownMenuItem(
                      value: provider,
                      enabled: provider.available,
                      child: Text(
                        provider.available
                            ? provider.label
                            : '${provider.label} — ${lcm.mailProviderUnavailable}',
                      ),
                    ),
                ],
                onChanged: widget.initialAccount == null
                    ? (value) {
                        if (value != null) setState(() => _provider = value);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: dataFieldDecoration(lcm.mailEmail),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayName,
                decoration: dataFieldDecoration(lcm.mailDisplayName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientId,
                decoration: dataFieldDecoration(
                  lcm.mailClientId,
                  hint: lcm.mailClientIdHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientSecret,
                obscureText: true,
                decoration: dataFieldDecoration(
                  lcm.mailClientSecret,
                  hint: lcm.mailClientSecretHint,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lcm.mailPrivate),
                value: _private,
                onChanged: (value) => setState(() => _private = value),
              ),
              Text(
                lcm.mailRedirectHint(MailProviderType.redirectUri),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                lcm.mailOAuthHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(lcm.mailConnect)),
      ],
    );
  }
}
