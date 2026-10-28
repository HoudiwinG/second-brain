import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/llm_config_controller.dart';
import '../domain/llm_endpoint.dart';
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
    final controller = ref.read(llmConfigControllerProvider.notifier);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _LlmConfigDialog(
        lcm: lcm,
        config: config,
        makeDefaultInitially: configs.isEmpty,
        onSave: (draft) => config == null
            ? controller.create(draft)
            : controller.updateConfig(config.id, draft),
      ),
    );
    if (saved == true && context.mounted) {
      showMessageSnackBar(context, lcm.llmConfigSaved);
    }
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
          '${config.baseUrl} · ${lcm.llmMaxTokens}: ${config.maxTokens}\n'
          '${config.hasApiKey ? lcm.llmApiKeyStored : lcm.llmApiKeyNotStored}',
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
    final controller = ref.read(llmConfigControllerProvider.notifier);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _LlmConfigDialog(
        lcm: lcm,
        config: config,
        makeDefaultInitially: false,
        onSave: (draft) => controller.updateConfig(config.id, draft),
      ),
    );
    if (saved == true && context.mounted) {
      showMessageSnackBar(context, lcm.llmConfigSaved);
    }
  }
}

class _LlmConfigDialog extends StatefulWidget {
  const _LlmConfigDialog({
    required this.lcm,
    required this.config,
    required this.makeDefaultInitially,
    required this.onSave,
  });

  final AppLocalizations lcm;
  final LlmProviderConfig? config;
  final bool makeDefaultInitially;
  final Future<bool> Function(LlmConfigDraft draft) onSave;

  @override
  State<_LlmConfigDialog> createState() => _LlmConfigDialogState();
}

class _LlmConfigDialogState extends State<_LlmConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late LlmProviderType _type;
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _embeddingModel;
  late final TextEditingController _apiKey;
  late final TextEditingController _maxTokens;
  late bool _isDefault;
  bool _deleteKey = false;
  bool _saving = false;
  String? _saveError;

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
    _embeddingModel = TextEditingController(
      text: config?.embeddingModel ?? _type.defaultEmbeddingModel ?? '',
    );
    _apiKey = TextEditingController();
    _maxTokens = TextEditingController(text: '${config?.maxTokens ?? 1024}');
    _isDefault = config?.isDefault ?? widget.makeDefaultInitially;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _embeddingModel.dispose();
    _apiKey.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  void _onTypeChanged(LlmProviderType? type) {
    if (type == null) return;
    final oldLabel = llmProviderLabel(widget.lcm, _type);
    final oldEmbedding = _type.defaultEmbeddingModel ?? '';
    setState(() {
      _type = type;
      if (_name.text.trim().isEmpty || _name.text.trim() == oldLabel) {
        _name.text = llmProviderLabel(widget.lcm, type);
      }
      _baseUrl.text = type.defaultBaseUrl;
      _model.text = type.defaultModel;
      if (_embeddingModel.text.trim().isEmpty ||
          _embeddingModel.text.trim() == oldEmbedding) {
        _embeddingModel.text = type.defaultEmbeddingModel ?? '';
      }
    });
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? widget.lcm.validationRequired
      : null;

  String? _validateBaseUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return widget.lcm.validationRequired;
    }
    return LlmEndpoint.isValid(value) ? null : widget.lcm.validationBaseUrl;
  }

  String? _validateMaxTokens(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 1 || parsed > 32768) {
      return widget.lcm.validationMaxTokens;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final maxTokens = int.tryParse(_maxTokens.text.trim());
    if (maxTokens == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final draft = LlmConfigDraft(
      type: _type,
      displayName: _name.text,
      baseUrl: _baseUrl.text,
      model: _model.text,
      embeddingModel: _embeddingModel.text,
      maxTokens: maxTokens,
      apiKey: _deleteKey
          ? ''
          : (_apiKey.text.trim().isEmpty ? null : _apiKey.text.trim()),
      isDefault: _isDefault,
    );
    final ok = await widget.onSave(draft);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _saveError = widget.lcm.llmConfigSaveError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lcm = widget.lcm;
    final editing = widget.config != null;
    final hasSavedKey = widget.config?.hasApiKey ?? false;
    return AlertDialog(
      title: Text(editing ? lcm.actionEdit : lcm.actionAddProvider),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                  onChanged: _saving ? null : _onTypeChanged,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  validator: _required,
                  decoration: dataFieldDecoration(lcm.llmConfigName),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _baseUrl,
                  validator: _validateBaseUrl,
                  decoration: dataFieldDecoration(lcm.llmBaseUrl),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  validator: _required,
                  decoration: dataFieldDecoration(lcm.llmModel),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _embeddingModel,
                  decoration: dataFieldDecoration(
                    lcm.llmEmbeddingModel,
                    hint: lcm.llmEmbeddingModelHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKey,
                  obscureText: true,
                  enabled: !_saving && !_deleteKey,
                  onChanged: (_) {
                    if (_deleteKey) setState(() => _deleteKey = false);
                  },
                  decoration: dataFieldDecoration(
                    lcm.llmApiKey,
                    hint: editing && hasSavedKey && !_deleteKey
                        ? lcm.llmApiKeyHint
                        : null,
                  ),
                ),
                if (editing && hasSavedKey) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _deleteKey
                              ? lcm.llmApiKeyDeleteHint
                              : lcm.llmApiKeyStored,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (!_deleteKey)
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _deleteKey = true),
                          child: Text(lcm.llmApiKeyDelete),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxTokens,
                  keyboardType: TextInputType.number,
                  validator: _validateMaxTokens,
                  decoration: dataFieldDecoration(lcm.llmMaxTokens),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lcm.llmDefaultBadge),
                  value: _isDefault,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isDefault = value),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(lcm.actionSave),
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
