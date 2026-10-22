import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/task_item.dart';

/// Экран задач: CRUD, приоритет, срок, статус, теги и приватность.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  Future<List<TaskItem>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TaskItem>> _load() async {
    final repo = await ref.read(tasksRepositoryProvider.future);
    return (await repo.list()).unwrap();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openEditor(TaskItem? task) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (dialogContext) => _TaskEditorDialog(task: task),
    );
    if (draft == null || !mounted) return;

    final repo = await ref.read(tasksRepositoryProvider.future);
    if (!mounted) return;
    final result = task == null
        ? await repo.create(draft)
        : await repo.update(task.id, draft);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) showErrorSnackBar(context, lcm, error);
      },
    );
  }

  Future<void> _toggle(TaskItem task) async {
    final repo = await ref.read(tasksRepositoryProvider.future);
    if (!mounted) return;
    final next = task.status == TaskStatus.done
        ? TaskStatus.todo
        : TaskStatus.done;
    final result = await repo.setStatus(task.id, next);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) {
          showErrorSnackBar(context, AppLocalizations.of(context)!, error);
        }
      },
    );
  }

  Future<void> _delete(TaskItem task) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(tasksRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.softDelete(task.id);
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
        title: Text(lcm.navTasks),
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
      body: FutureBuilder<List<TaskItem>>(
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
          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return EmptyListState(
              icon: Icons.checklist_outlined,
              message: lcm.tasksEmpty,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _TaskCard(
                task: task,
                onTap: () => _openEditor(task),
                onToggle: () => _toggle(task),
                onDelete: () => _delete(task),
              );
            },
          );
        },
      ),
    );
  }
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({required this.task});

  final TaskItem? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late TaskPriority _priority;
  late TaskStatus _status;
  DateTime? _dueAt;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _description = TextEditingController(text: widget.task?.description ?? '');
    _tags = TextEditingController(text: widget.task?.tags.join(', ') ?? '');
    _priority = widget.task?.priority ?? TaskPriority.normal;
    _status = widget.task?.status ?? TaskStatus.todo;
    _dueAt = widget.task?.dueAt;
    _isPrivate = widget.task?.isPrivateForLlm ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt?.toLocal() ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(picked.year, picked.month, picked.day, 12).toUtc();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.task == null ? lcm.actionAdd : lcm.actionEdit),
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
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: dataFieldDecoration(lcm.fieldDescription),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: dataFieldDecoration(lcm.fieldPriority),
                items: [
                  for (final value in TaskPriority.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(priorityLabel(lcm, value)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _priority = value ?? _priority),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: dataFieldDecoration(lcm.fieldStatus),
                items: [
                  for (final value in TaskStatus.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(statusLabel(lcm, value)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: dataFieldDecoration(lcm.fieldDueDate),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dueAt == null
                            ? lcm.fieldNoDueDate
                            : formatDate(context, _dueAt),
                      ),
                    ),
                    if (_dueAt != null)
                      IconButton(
                        tooltip: lcm.fieldNoDueDate,
                        onPressed: () => setState(() => _dueAt = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: lcm.fieldDueDate,
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ],
                ),
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
            TaskDraft(
              title: _title.text,
              description: _description.text,
              priority: _priority,
              dueAt: _dueAt,
              status: _status,
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final done = task.status == TaskStatus.done;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(value: done, onChanged: (_) => onToggle()),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: done
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
            ),
            if (task.isPrivateForLlm) const Icon(Icons.lock_outline, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(priorityLabel(lcm, task.priority)),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.flag_outlined, size: 16),
                ),
                Chip(
                  label: Text(statusLabel(lcm, task.status)),
                  visualDensity: VisualDensity.compact,
                ),
                if (task.dueAt != null)
                  Chip(
                    label: Text(formatDate(context, task.dueAt)),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.event_outlined, size: 16),
                  ),
                for (final tag in task.tags)
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
              ],
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
