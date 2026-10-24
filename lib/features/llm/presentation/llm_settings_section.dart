import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/llm_config_controller.dart';
import '../domain/llm_provider_config.dart';
import '../domain/llm_provider_type.dart';

/// Секция настроек LLM-провайдеров и ключей.
class LlmSettingsSection extends ConsumerWidget {
  const LlmSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lcm = AppLocalizations.of(context)!;
    final configs = ref.watch(llmConfigControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lcm.settingsLlmSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openEditor(context, ref, lcm, null),
              icon: const Icon(Icons.add_outlined),
              label: Text(lcm.actionAddProvider),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(lcm.settingsLlmHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        configs.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => ErrorState(
            message: lcm.errorUnexpected,
            retryLabel: lcm.retryAction,
            onRetry: () => ref.invalidate(llmConfigControllerProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(lcm.llmNoConfigs),
                  trailing: FilledButton(
                    onPressed: () => _openEditor(context, ref, lcm, null),
                    child: Text(lcm.actionAddProvider),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final config in items) ...[
                  _ConfigCard(config: config),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
    LlmProviderConfig? config,
  ) async {
    final configs = ref.read(llmConfigControllerProvider).value ?? const [];
    final draft = await showDialog<LlmConfigDraft>(
      context: context,
      builder: (dialogContext) => _LlmConfigDialog(
        lcm: lcm,
        config: config,
        makeDefaultInitially: configs.isEmpty,
      ),
    );
    if (draft == null || !context.mounted) return;
    final controller = ref.read(llmConfigControllerProvider.notifier);
    final saved = config == null
        ? await controller.create(draft)
        : await controller.updateConfig(config.id, draft);
    if (!context.mounted) return;
    showMessageSnackBar(
      context,
      saved ? lcm.llmConfigSaved : lcm.llmConfigSaveError,
    );
  }
}

class _ConfigCard extends ConsumerWidget {
  const _ConfigCard({required this.config});

  final LlmProviderConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lcm = AppLocalizations.of(context)!;
    final providerLabel = llmProviderLabel(lcm, config.type);
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: Icon(
          config.isDefault
              ? Icons.check_circle_outline
              : Icons.extension_outlined,
        ),
        title: Row(
          children: [
            Flexible(child: Text(config.displayName)),
            if (config.isDefault) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(lcm.llmDefaultBadge),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$providerLabel · ${config.model}\n'
          '${config.baseUrl} · ${lcm.llmMaxTokens}: ${config.maxTokens}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: lcm.actionEdit,
              onPressed: () => _openEdit(context, ref, lcm),
              icon: const Icon(Icons.edit_outlined),
            ),
            if (!config.isDefault)
              IconButton(
                tooltip: lcm.actionSetDefault,
                onPressed: () async {
                  final ok = await ref
                      .read(llmConfigControllerProvider.notifier)
                      .setDefault(config.id);
                  if (!context.mounted) return;
                  showMessageSnackBar(
                    context,
                    ok ? lcm.llmDefaultSet : lcm.llmDefaultError,
                  );
                },
                icon: const Icon(Icons.star_outline),
              ),
            IconButton(
              tooltip: lcm.actionDelete,
              onPressed: () async {
                final confirmed = await confirmDelete(context, lcm);
                if (!confirmed || !context.mounted) return;
                final ok = await ref
                    .read(llmConfigControllerProvider.notifier)
                    .delete(config.id);
                if (!context.mounted) return;
                showMessageSnackBar(
                  context,
                  ok ? lcm.llmConfigDeleted : lcm.llmConfigDeleteError,
                );
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
  ) async {
    final draft = await showDialog<LlmConfigDraft>(
      context: context,
      builder: (dialogContext) =>
          _LlmConfigDialog(lcm: lcm, config: config, makeDefaultInitially: false),
    );
    if (draft == null || !context.mounted) return;
    final ok = await ref
        .read(llmConfigControllerProvider.notifier)
        .updateConfig(config.id, draft);
    if (!context.mounted) return;
    showMessageSnackBar(context, ok ? lcm.llmConfigSaved : lcm.llmConfigSaveError);
  }
}

class _LlmConfigDialog extends StatefulWidget {
  const _LlmConfigDialog({
    required this.lcm,
    required this.config,
    required this.makeDefaultInitially,
  });

  final AppLocalizations lcm;
  final LlmProviderConfig? config;
  final bool makeDefaultInitially;

  @override
  State<_LlmConfigDialog> createState() => _LlmConfigDialogState();
}

class _LlmConfigDialogState extends State<_LlmConfigDialog> {
  late LlmProviderType _type;
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late final TextEditingController _maxTokens;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _type = config?.type ?? LlmProviderType.openai;
    _name = TextEditingController(
      text: config?.displayName ?? llmProviderLabel(widget.lcm, _type),
    );
    _baseUrl = TextEditingController(
      text: config?.baseUrl ?? _type.defaultBaseUrl,
    );
    _model = TextEditingController(text: config?.model ?? _type.defaultModel);
    _apiKey = TextEditingController();
    _maxTokens = TextEditingController(
      text: '${config?.maxTokens ?? 1024}',
    );
    _isDefault = config?.isDefault ?? widget.makeDefaultInitially;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  void _onTypeChanged(LlmProviderType? type) {
    if (type == null) return;
    final oldLabel = llmProviderLabel(widget.lcm, _type);
    setState(() {
      _type = type;
      if (_name.text.trim().isEmpty || _name.text.trim() == oldLabel) {
        _name.text = llmProviderLabel(widget.lcm, type);
      }
      _baseUrl.text = type.defaultBaseUrl;
      _model.text = type.defaultModel;
    });
  }

  void _submit() {
    final maxTokens = int.tryParse(_maxTokens.text.trim()) ?? 1024;
    Navigator.of(context).pop(
      LlmConfigDraft(
        type: _type,
        displayName: _name.text,
        baseUrl: _baseUrl.text,
        model: _model.text,
        maxTokens: maxTokens,
        apiKey: _apiKey.text.isEmpty ? null : _apiKey.text,
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = widget.lcm;
    final editing = widget.config != null;
    return AlertDialog(
      title: Text(
        editing ? lcm.actionEdit : lcm.actionAddProvider,
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<LlmProviderType>(
                initialValue: _type,
                decoration: dataFieldDecoration(lcm.llmProviderLabel),
                items: [
                  for (final type in LlmProviderType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(llmProviderLabel(lcm, type)),
                    ),
                ],
                onChanged: _onTypeChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: dataFieldDecoration(lcm.llmConfigName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrl,
                decoration: dataFieldDecoration(lcm.llmBaseUrl),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                decoration: dataFieldDecoration(lcm.llmModel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKey,
                obscureText: true,
                decoration: dataFieldDecoration(
                  lcm.llmApiKey,
                  hint: editing ? lcm.llmApiKeyHint : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxTokens,
                keyboardType: TextInputType.number,
                decoration: dataFieldDecoration(lcm.llmMaxTokens),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lcm.llmDefaultBadge),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(lcm.actionSave),
        ),
      ],
    );
  }
}

/// Локализованное имя провайдера.
String llmProviderLabel(AppLocalizations lcm, LlmProviderType type) =>
    switch (type) {
      LlmProviderType.openai => lcm.llmProviderOpenai,
      LlmProviderType.openaiCompatible => lcm.llmProviderOpenaiCompatible,
      LlmProviderType.anthropic => lcm.llmProviderAnthropic,
      LlmProviderType.google => lcm.llmProviderGoogle,
    };
