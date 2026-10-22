import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/idea_entry.dart';

/// Дневник идей: CRUD, источник, настроение, теги и приватность.
class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key});

  @override
  ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
  Future<List<IdeaEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<IdeaEntry>> _load() async {
    final repo = await ref.read(ideasRepositoryProvider.future);
    return (await repo.list()).unwrap();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openEditor(IdeaEntry? idea) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<IdeaDraft>(
      context: context,
      builder: (dialogContext) => _IdeaEditorDialog(idea: idea),
    );
    if (draft == null || !mounted) return;

    final repo = await ref.read(ideasRepositoryProvider.future);
    if (!mounted) return;
    final result = idea == null
        ? await repo.create(draft)
        : await repo.update(idea.id, draft);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) showErrorSnackBar(context, lcm, error);
      },
    );
  }

  Future<void> _delete(IdeaEntry idea) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(ideasRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.softDelete(idea.id);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) showErrorSnackBar(context, lcm, error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.navIdeas),
        actions: [
          IconButton(
            tooltip: lcm.actionRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add),
        label: Text(lcm.actionAdd),
      ),
      body: FutureBuilder<List<IdeaEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: lcm.errorUnexpected,
              retryLabel: lcm.retryAction,
              onRetry: _reload,
            );
          }
          final ideas = snapshot.data!;
          if (ideas.isEmpty) {
            return EmptyListState(
              icon: Icons.lightbulb_outline,
              message: lcm.ideasEmpty,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: ideas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final idea = ideas[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _openEditor(idea),
                  title: Row(
                    children: [
                      Expanded(child: Text(idea.text)),
                      if (idea.isPrivateForLlm)
                        const Icon(Icons.lock_outline, size: 18),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (idea.source != null)
                            Chip(
                              label: Text(idea.source!),
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(
                                Icons.travel_explore_outlined,
                                size: 16,
                              ),
                            ),
                          if (idea.mood != null)
                            Chip(
                              label: Text(idea.mood!),
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(
                                Icons.sentiment_satisfied_outlined,
                                size: 16,
                              ),
                            ),
                          for (final tag in idea.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateTime(context, idea.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: lcm.actionDelete,
                    onPressed: () => _delete(idea),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IdeaEditorDialog extends StatefulWidget {
  const _IdeaEditorDialog({required this.idea});

  final IdeaEntry? idea;

  @override
  State<_IdeaEditorDialog> createState() => _IdeaEditorDialogState();
}

class _IdeaEditorDialogState extends State<_IdeaEditorDialog> {
  late final TextEditingController _text;
  late final TextEditingController _source;
  late final TextEditingController _mood;
  late final TextEditingController _tags;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.idea?.text ?? '');
    _source = TextEditingController(text: widget.idea?.source ?? '');
    _mood = TextEditingController(text: widget.idea?.mood ?? '');
    _tags = TextEditingController(text: widget.idea?.tags.join(', ') ?? '');
    _isPrivate = widget.idea?.isPrivateForLlm ?? false;
  }

  @override
  void dispose() {
    _text.dispose();
    _source.dispose();
    _mood.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.idea == null ? lcm.actionAdd : lcm.actionEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                decoration: dataFieldDecoration(lcm.fieldIdeaText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                decoration: dataFieldDecoration(lcm.fieldSource),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mood,
                decoration: dataFieldDecoration(lcm.fieldMood),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: dataFieldDecoration(lcm.fieldTags),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lcm.fieldPrivate),
                value: _isPrivate,
                onChanged: (value) => setState(() => _isPrivate = value),
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
          onPressed: () => Navigator.of(context).pop(
            IdeaDraft(
              text: _text.text,
              source: _source.text.isEmpty ? null : _source.text,
              mood: _mood.text.isEmpty ? null : _mood.text,
              tags: parseTags(_tags.text),
              isPrivateForLlm: _isPrivate,
            ),
          ),
          child: Text(lcm.actionSave),
        ),
      ],
    );
  }
}
