import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../finance/domain/finance_transaction.dart';
import '../../learning/domain/learning_session.dart';
import '../domain/analytics_summary.dart';

/// Аналитика по локальным данным: задачи, обучение, почта и финансы.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Future<AnalyticsSummary>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AnalyticsSummary> _load() async {
    final notesRepo = await ref.read(notesRepositoryProvider.future);
    final ideasRepo = await ref.read(ideasRepositoryProvider.future);
    final tasksRepo = await ref.read(tasksRepositoryProvider.future);
    final learningRepo = await ref.read(learningRepositoryProvider.future);
    final mailRepo = await ref.read(mailRepositoryProvider.future);
    final financeRepo = await ref.read(financeRepositoryProvider.future);

    final notes = (await notesRepo.list()).unwrap();
    final ideas = (await ideasRepo.list()).unwrap();
    final tasks = (await tasksRepo.list()).unwrap();
    final tracks = (await learningRepo.listTracks()).unwrap();
    final sessions = <LearningSession>[];
    for (final track in tracks) {
      sessions.addAll((await learningRepo.listSessions(track.id)).unwrap());
    }
    final mailCount = (await mailRepo.countMessages()).unwrap();
    final finance = (await financeRepo.list(
      currency: FinanceDraft.defaultCurrency,
    )).unwrap();
    return buildAnalyticsSummary(
      notes: notes,
      ideas: ideas,
      tasks: tasks,
      tracks: tracks,
      sessions: sessions,
      mailMessages: mailCount,
      finance: finance,
      currency: FinanceDraft.defaultCurrency,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.analyticsTitle),
        actions: [
          IconButton(
            tooltip: lcm.actionRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<AnalyticsSummary>(
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
              _MetricCard(
                title: lcm.analyticsTasks,
                rows: [
                  _MetricRow(lcm.analyticsTasksOpen, data.tasksOpen),
                  _MetricRow(lcm.analyticsTasksDone, data.tasksDone),
                  _MetricRow(lcm.analyticsTasksOverdue, data.tasksOverdue),
                ],
              ),
              const SizedBox(height: 12),
              _MetricCard(
                title: lcm.analyticsLearning,
                rows: [
                  _MetricRow(lcm.analyticsTracks, data.learningTracks),
                  _MetricRow(lcm.analyticsSessions, data.learningSessions),
                  _MetricRow(lcm.analyticsMinutes, data.learningMinutes),
                ],
              ),
              const SizedBox(height: 12),
              _MetricCard(
                title: lcm.analyticsNotes,
                rows: [
                  _MetricRow(lcm.analyticsNotes, data.notes),
                  _MetricRow(lcm.analyticsIdeas, data.ideas),
                  _MetricRow(lcm.analyticsMail, data.mailMessages),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lcm.analyticsFinance,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${lcm.analyticsIncome}: '
                        '${data.income.toStringAsFixed(2)} '
                        '${FinanceDraft.defaultCurrency}',
                      ),
                      Text(
                        '${lcm.analyticsExpense}: '
                        '${data.expense.toStringAsFixed(2)} '
                        '${FinanceDraft.defaultCurrency}',
                      ),
                      Text(
                        '${lcm.analyticsBalance}: '
                        '${data.balance.toStringAsFixed(2)} '
                        '${FinanceDraft.defaultCurrency}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${lcm.analyticsTransactions}: ${data.transactions}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 24),
                      Text(
                        lcm.analyticsTopExpenses,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (data.topExpenses.isEmpty)
                        Text(lcm.analyticsNoExpenses)
                      else
                        for (final entry in data.topExpenses) ...[
                          Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Text(entry.value.toStringAsFixed(2)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: data.expense == 0
                                ? 0
                                : (entry.value / data.expense).clamp(0, 1),
                          ),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.rows});

  final String title;
  final List<_MetricRow> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(row.label)),
                  Text(
                    '${row.value}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _MetricRow {
  const _MetricRow(this.label, this.value);

  final String label;
  final int value;
}
