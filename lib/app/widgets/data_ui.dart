import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../../features/finance/domain/finance_transaction.dart';
import '../../features/search/domain/search_hit.dart';
import '../../features/tasks/domain/task_item.dart';
import '../../l10n/generated/app_localizations.dart';

/// Общие UI-помощники экранов ядра данных stage-01.

String formatDate(BuildContext context, DateTime? value) {
  if (value == null) return AppLocalizations.of(context)!.dateNotSet;
  return MaterialLocalizations.of(context).formatShortDate(value.toLocal());
}

String formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatShortDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date $time';
}

List<String> parseTags(String raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final part in raw.split(',')) {
    final tag = part.trim();
    if (tag.isEmpty) continue;
    if (seen.add(tag.toLowerCase())) result.add(tag);
  }
  return result;
}

InputDecoration dataFieldDecoration(String label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );

void showErrorSnackBar(
  BuildContext context,
  AppLocalizations lcm,
  AppException error,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${lcm.errorDetails}: ${error.message}')),
  );
}

void showMessageSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDelete(BuildContext context, AppLocalizations lcm) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(lcm.actionDelete),
      content: Text(lcm.deleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(lcm.actionDelete),
        ),
      ],
    ),
  );
  return result ?? false;
}

String priorityLabel(AppLocalizations lcm, TaskPriority value) =>
    switch (value) {
      TaskPriority.low => lcm.priorityLow,
      TaskPriority.normal => lcm.priorityNormal,
      TaskPriority.high => lcm.priorityHigh,
      TaskPriority.urgent => lcm.priorityUrgent,
    };

String statusLabel(AppLocalizations lcm, TaskStatus value) => switch (value) {
  TaskStatus.todo => lcm.statusTodo,
  TaskStatus.inProgress => lcm.statusInProgress,
  TaskStatus.done => lcm.statusDone,
  TaskStatus.cancelled => lcm.statusCancelled,
};

String financeTypeLabel(AppLocalizations lcm, FinanceTransactionType value) =>
    switch (value) {
      FinanceTransactionType.income => lcm.financeIncome,
      FinanceTransactionType.expense => lcm.financeExpense,
    };

String searchTypeLabel(AppLocalizations lcm, SearchEntityType value) =>
    switch (value) {
      SearchEntityType.note => lcm.searchTypeNote,
      SearchEntityType.task => lcm.searchTypeTask,
      SearchEntityType.idea => lcm.searchTypeIdea,
      SearchEntityType.finance => lcm.searchTypeFinance,
    };

/// Пустое состояние списка.
class EmptyListState extends StatelessWidget {
  const EmptyListState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Ошибка загрузки/операции с кнопкой повтора.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
