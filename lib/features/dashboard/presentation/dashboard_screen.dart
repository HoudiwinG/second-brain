import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/feature_directions.dart';
import '../../../app/router.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../finance/domain/finance_transaction.dart';
import '../../ideas/domain/idea_entry.dart';
import '../../notes/domain/note.dart';
import '../../quick_capture/presentation/quick_capture_dialog.dart';
import '../../tasks/domain/task_item.dart';

/// Главный экран: сводка дня, быстрые действия и последние записи.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<_DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    final tasksRepo = await ref.read(tasksRepositoryProvider.future);
    final notesRepo = await ref.read(notesRepositoryProvider.future);
    final ideasRepo = await ref.read(ideasRepositoryProvider.future);
    final financeRepo = await ref.read(financeRepositoryProvider.future);

    final tasks = (await tasksRepo.list()).unwrap();
    final notes = (await notesRepo.list()).unwrap();
    final ideas = (await ideasRepo.list()).unwrap();
    final summary = (await financeRepo.summary(
      from: monthStart.toUtc(),
      to: monthEnd.toUtc(),
    )).unwrap();

    final open = tasks.where(
      (task) =>
          task.status != TaskStatus.done &&
          task.status != TaskStatus.cancelled &&
          !task.isDeleted,
    );
    final overdue = <TaskItem>[];
    final today = <TaskItem>[];
    for (final task in open) {
      final at = (task.dueAt ?? task.remindAt)?.toLocal();
      if (at == null) continue;
      if (at.isBefore(dayStart)) {
        overdue.add(task);
      } else if (!at.isBefore(dayEnd)) {
        continue;
      } else {
        today.add(task);
      }
    }
    int byDate(TaskItem a, TaskItem b) => (a.dueAt ?? a.remindAt!)
        .compareTo(b.dueAt ?? b.remindAt!);
    overdue.sort(byDate);
    today.sort(byDate);

    return _DashboardData(
      overdueTasks: overdue,
      todayTasks: today,
      recentNotes: notes.take(4).toList(),
      recentIdeas: ideas.take(3).toList(),
      finance: summary,
      now: now,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _quickCapture(QuickCaptureKind kind) async {
    final saved = await showQuickCaptureDialog(context, initialKind: kind);
    if (saved == true && mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.navDashboard),
        actions: [
          IconButton(
            tooltip: lcm.actionRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _quickCapture(QuickCaptureKind.note),
        icon: const Icon(Icons.bolt_outlined),
        label: Text(lcm.quickCaptureTitle),
      ),
      body: FutureBuilder<_DashboardData>(
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
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatFullDate(data.now),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  lcm.dashboardQuickActions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAction(
                      icon: Icons.sticky_note_2_outlined,
                      label: lcm.quickCaptureNote,
                      onTap: () => _quickCapture(QuickCaptureKind.note),
                    ),
                    _QuickAction(
                      icon: Icons.checklist_outlined,
                      label: lcm.quickCaptureTask,
                      onTap: () => _quickCapture(QuickCaptureKind.task),
                    ),
                    _QuickAction(
                      icon: Icons.lightbulb_outline,
                      label: lcm.quickCaptureIdea,
                      onTap: () => _quickCapture(QuickCaptureKind.idea),
                    ),
                    _QuickAction(
                      icon: Icons.savings_outlined,
                      label: lcm.quickCaptureFinance,
                      onTap: () => _quickCapture(QuickCaptureKind.finance),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: lcm.dashboardTodayTasks,
                  actionLabel: lcm.dashboardAll,
                  onAction: () => context.go(pathForBranch(FeatureBranch.tasks)),
                ),
                if (data.overdueTasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    lcm.dashboardOverdueTasks(data.overdueTasks.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (data.overdueTasks.isEmpty && data.todayTasks.isEmpty)
                  _EmptyHint(text: lcm.dashboardTasksEmpty)
                else
                  for (final task in [
                    ...data.overdueTasks,
                    ...data.todayTasks,
                  ].take(7))
                    _TaskRow(
                      task: task,
                      overdue: data.overdueTasks.contains(task),
                      onTap: () =>
                          context.go(pathForBranch(FeatureBranch.tasks)),
                    ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: lcm.dashboardRecentNotes,
                  actionLabel: lcm.dashboardAll,
                  onAction: () => context.go(pathForBranch(FeatureBranch.notes)),
                ),
                const SizedBox(height: 8),
                if (data.recentNotes.isEmpty)
                  _EmptyHint(text: lcm.dashboardNotesEmpty)
                else
                  for (final note in data.recentNotes) _NoteRow(note: note),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: lcm.dashboardRecentIdeas,
                  actionLabel: lcm.dashboardAll,
                  onAction: () => context.go(pathForBranch(FeatureBranch.ideas)),
                ),
                const SizedBox(height: 8),
                if (data.recentIdeas.isEmpty)
                  _EmptyHint(text: lcm.dashboardIdeasEmpty)
                else
                  for (final idea in data.recentIdeas) _IdeaRow(idea: idea),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: lcm.dashboardFinanceMonth,
                  actionLabel: lcm.dashboardAll,
                  onAction: () =>
                      context.go(pathForBranch(FeatureBranch.finance)),
                ),
                const SizedBox(height: 8),
                _FinanceCard(summary: data.finance),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.overdueTasks,
    required this.todayTasks,
    required this.recentNotes,
    required this.recentIdeas,
    required this.finance,
    required this.now,
  });

  final List<TaskItem> overdueTasks;
  final List<TaskItem> todayTasks;
  final List<Note> recentNotes;
  final List<IdeaEntry> recentIdeas;
  final FinanceSummary finance;
  final DateTime now;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.overdue,
    required this.onTap,
  });

  final TaskItem task;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final at = task.dueAt ?? task.remindAt;
    final color = overdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          overdue ? Icons.warning_amber_outlined : Icons.today_outlined,
          color: color,
        ),
        title: Text(task.title),
        subtitle: Text(
          [
            if (at != null) formatDateTime(context, at),
            priorityLabel(lcm, task.priority),
          ].join(' · '),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.sticky_note_2_outlined),
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: note.body.trim().isEmpty
            ? null
            : Text(note.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          formatDateTime(context, note.updatedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _IdeaRow extends StatelessWidget {
  const _IdeaRow({required this.idea});

  final IdeaEntry idea;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lightbulb_outline),
        title: Text(idea.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatDateTime(context, idea.createdAt)),
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final error = Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _FinanceCell(
              label: lcm.financeIncome,
              value: summary.income.toStringAsFixed(2),
              color: Colors.green.shade700,
            ),
            _FinanceCell(
              label: lcm.financeExpense,
              value: summary.expense.toStringAsFixed(2),
              color: error,
            ),
            _FinanceCell(
              label: lcm.financeBalance,
              value: summary.balance.toStringAsFixed(2),
              color: summary.balance >= 0
                  ? Theme.of(context).colorScheme.primary
                  : error,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceCell extends StatelessWidget {
  const _FinanceCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
