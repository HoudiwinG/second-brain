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
  Future<_MailData>? _future;
  int? _selectedAccountId;
  String _query = '';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
    final draft = await showDialog<MailAccountDraft>(
      context: context,
      builder: (_) => const _MailAccountDialog(),
    );
    if (draft == null || !mounted) return;
    final oauth = ref.read(mailOAuthServiceProvider);
    final result = await oauth.connect(
      draft.provider,
      clientId: draft.clientId,
      loginHint: draft.email,
    );
    if (!mounted) return;
    if (result is Failure<MailTokens>) {
      showMessageSnackBar(context, lcm.mailOAuthError);
      return;
    }
    final tokens = (result as Success<MailTokens>).value;
    final repo = await ref.read(mailRepositoryProvider.future);
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

  Future<void> _summarize(MailMessage message) async {
    final lcm = AppLocalizations.of(context)!;
    final service = await ref.read(mailSummaryServiceProvider.future);
    final result = await service.summarizeMessage(message);
    if (!mounted) return;
    result.when(
      success: (text) => _showText(lcm.mailSummary, text),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _createTask(MailMessage message) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(tasksRepositoryProvider.future);
    final result = await repo.create(
      TaskDraft(
        title: message.displayTitle,
        description: message.body.isEmpty ? message.snippet : message.body,
        isPrivateForLlm: message.isPrivateForLlm,
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
        title: Text(message.displayTitle),
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
                if (message.isPrivateForLlm) ...[
                  const SizedBox(height: 12),
                  Text(
                    lcm.mailPrivate,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
      body: FutureBuilder<_MailData>(
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
                const SizedBox(height: 8),
                TextField(
                  decoration: dataFieldDecoration(lcm.mailSearchHint),
                  onChanged: (value) {
                    _query = value;
                    _reload();
                  },
                ),
                const SizedBox(height: 8),
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
                        title: Text(message.displayTitle),
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
    required this.onDelete,
    required this.onPrivate,
  });

  final MailAccount account;
  final bool syncing;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onSync;
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
  const _MailAccountDialog();

  @override
  State<_MailAccountDialog> createState() => _MailAccountDialogState();
}

class _MailAccountDialogState extends State<_MailAccountDialog> {
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _clientId = TextEditingController();
  MailProviderType _provider = MailProviderType.gmail;
  bool _private = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    _clientId.dispose();
    super.dispose();
  }

  void _submit() {
    final lcm = AppLocalizations.of(context)!;
    if (!_email.text.contains('@') || _clientId.text.trim().isEmpty) {
      setState(() => _error = lcm.mailOAuthMissing);
      return;
    }
    Navigator.of(context).pop(
      MailAccountDraft(
        provider: _provider,
        email: _email.text,
        displayName: _displayName.text,
        clientId: _clientId.text,
        isPrivateForLlm: _private,
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
                      child: Text(provider.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _provider = value);
                },
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lcm.mailPrivate),
                value: _private,
                onChanged: (value) => setState(() => _private = value),
              ),
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
