import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/category.dart';
import '../domain/note.dart';

/// Экран заметок: CRUD, категории, теги и флаг приватности.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  Future<_NotesData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_NotesData> _load() async {
    final notesRepo = await ref.read(notesRepositoryProvider.future);
    final categoriesRepo = await ref.read(categoriesRepositoryProvider.future);
    final notes = (await notesRepo.list()).unwrap();
    final categories = (await categoriesRepo.list()).unwrap();
    return _NotesData(notes: notes, categories: categories);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openEditor(Note? note, List<Category> categories) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<NoteDraft>(
      context: context,
      builder: (dialogContext) =>
          _NoteEditorDialog(note: note, categories: categories),
    );
    if (draft == null || !mounted) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    if (!mounted) return;
    final result = note == null
        ? await repo.create(draft)
        : await repo.update(note.id, draft);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) showErrorSnackBar(context, lcm, error);
      },
    );
  }

  Future<void> _delete(Note note) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(notesRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.softDelete(note.id);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) showErrorSnackBar(context, lcm, error);
      },
    );
  }

  Future<void> _openCategories() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _CategoryManagerDialog(),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.navNotes),
        actions: [
          IconButton(
            tooltip: lcm.actionCategories,
            onPressed: _openCategories,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: lcm.actionRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final data = _future;
          if (data == null) return;
          data.then((value) {
            if (mounted) _openEditor(null, value.categories);
          });
        },
        icon: const Icon(Icons.add),
        label: Text(lcm.actionAdd),
      ),
      body: FutureBuilder<_NotesData>(
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
          final data = snapshot.data!;
          if (data.notes.isEmpty) {
            return EmptyListState(
              icon: Icons.sticky_note_2_outlined,
              message: lcm.notesEmpty,
            );
          }
          final categoryNames = {
            for (final category in data.categories) category.id: category.name,
          };
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: data.notes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final note = data.notes[index];
              return _NoteCard(
                note: note,
                categoryName: note.categoryId == null
                    ? null
                    : categoryNames[note.categoryId],
                onTap: () => _openEditor(note, data.categories),
                onDelete: () => _delete(note),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({required this.note, required this.categories});

  final Note? note;
  final List<Category> categories;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  late int _categoryId;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _tags = TextEditingController(text: widget.note?.tags.join(', ') ?? '');
    _categoryId = widget.note?.categoryId ?? 0;
    _isPrivate = widget.note?.isPrivateForLlm ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.note == null ? lcm.actionAdd : lcm.actionEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: dataFieldDecoration(lcm.fieldTitle),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 8,
                decoration: dataFieldDecoration(lcm.fieldBody),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: dataFieldDecoration(lcm.fieldTags),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: dataFieldDecoration(lcm.fieldCategory),
                items: [
                  DropdownMenuItem(value: 0, child: Text(lcm.categoryNone)),
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value ?? 0),
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
            NoteDraft(
              title: _title.text,
              body: _body.text,
              categoryId: _categoryId == 0 ? null : _categoryId,
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

class _NotesData {
  const _NotesData({required this.notes, required this.categories});

  final List<Note> notes;
  final List<Category> categories;
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.categoryName,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final String? categoryName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(child: Text(note.title)),
            if (note.isPrivateForLlm)
              Chip(
                label: Text(lcm.privateBadge),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.lock_outline, size: 16),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.body.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (categoryName != null)
                  Chip(
                    label: Text(categoryName!),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.folder_outlined, size: 16),
                  ),
                for (final tag in note.tags)
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatDateTime(context, note.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: lcm.actionDelete,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

/// Диалог управления категориями (иерархия и удаление).
class _CategoryManagerDialog extends ConsumerStatefulWidget {
  const _CategoryManagerDialog();

  @override
  ConsumerState<_CategoryManagerDialog> createState() =>
      _CategoryManagerDialogState();
}

class _CategoryManagerDialogState
    extends ConsumerState<_CategoryManagerDialog> {
  final _name = TextEditingController();
  var _parentId = 0;
  var _loading = true;
  var _saving = false;
  List<Category> _categories = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await ref.read(categoriesRepositoryProvider.future);
    final result = await repo.list();
    if (!mounted) return;
    result.when(
      success: (value) => setState(() {
        _categories = value;
        _loading = false;
        _error = null;
      }),
      failure: (error) => setState(() {
        _loading = false;
        _error = error.message;
      }),
    );
  }

  Future<void> _create() async {
    final lcm = AppLocalizations.of(context)!;
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = await ref.read(categoriesRepositoryProvider.future);
    final result = await repo.create(
      name: _name.text,
      parentId: _parentId == 0 ? null : _parentId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        _name.clear();
        _load();
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _delete(Category category) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(categoriesRepositoryProvider.future);
    final result = await repo.delete(category.id);
    if (!mounted) return;
    result.when(
      success: (_) => _load(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.actionCategories),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: dataFieldDecoration(lcm.fieldNewCategory),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _create,
                  child: Text(lcm.actionAdd),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _parentId,
              decoration: dataFieldDecoration(lcm.categoryParent),
              items: [
                DropdownMenuItem(value: 0, child: Text(lcm.categoryNone)),
                for (final category in _categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => setState(() => _parentId = value ?? 0),
            ),
            const Divider(height: 24),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: ErrorState(
                  message: _error!,
                  retryLabel: lcm.retryAction,
                  onRetry: _load,
                ),
              )
            else if (_categories.isEmpty)
              Expanded(
                child: EmptyListState(
                  icon: Icons.category_outlined,
                  message: lcm.categoriesEmpty,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(category.name),
                      subtitle: category.parentId == null
                          ? null
                          : Text(
                              _categories
                                  .firstWhere(
                                    (c) => c.id == category.parentId,
                                    orElse: () => category,
                                  )
                                  .name,
                            ),
                      trailing: IconButton(
                        tooltip: lcm.actionDelete,
                        onPressed: () => _delete(category),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
      ],
    );
  }
}
