import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/finance_transaction.dart';

/// Финансы: CRUD операций и сводка доходов/расходов.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  Future<_FinanceData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FinanceData> _load() async {
    final repo = await ref.read(financeRepositoryProvider.future);
    final items = (await repo.list()).unwrap();
    final summary = (await repo.summary()).unwrap();
    return _FinanceData(items: items, summary: summary);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openEditor(FinanceTransaction? transaction) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<FinanceDraft>(
      context: context,
      builder: (dialogContext) =>
          _FinanceEditorDialog(transaction: transaction),
    );
    if (draft == null || !mounted) return;

    final repo = await ref.read(financeRepositoryProvider.future);
    if (!mounted) return;
    final result = transaction == null
        ? await repo.create(draft)
        : await repo.update(transaction.id, draft);
    result.when(
      success: (_) {
        if (mounted) _reload();
      },
      failure: (error) {
        if (mounted) showErrorSnackBar(context, lcm, error);
      },
    );
  }

  Future<void> _delete(FinanceTransaction transaction) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(financeRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.softDelete(transaction.id);
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
        title: Text(lcm.navFinance),
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
      body: FutureBuilder<_FinanceData>(
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _SummaryCard(summary: data.summary),
              const SizedBox(height: 16),
              if (data.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: EmptyListState(
                    icon: Icons.savings_outlined,
                    message: lcm.financeEmpty,
                  ),
                )
              else
                for (final transaction in data.items) ...[
                  _TransactionCard(
                    transaction: transaction,
                    onTap: () => _openEditor(transaction),
                    onDelete: () => _delete(transaction),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _FinanceData {
  const _FinanceData({required this.items, required this.summary});

  final List<FinanceTransaction> items;
  final FinanceSummary summary;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryCell(
              label: lcm.financeIncome,
              value: summary.income.toStringAsFixed(2),
              color: Colors.green.shade700,
            ),
            _SummaryCell(
              label: lcm.financeExpense,
              value: summary.expense.toStringAsFixed(2),
              color: scheme.error,
            ),
            _SummaryCell(
              label: lcm.financeBalance,
              value: summary.balance.toStringAsFixed(2),
              color: summary.balance >= 0
                  ? scheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
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
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  final FinanceTransaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final income = transaction.type == FinanceTransactionType.income;
    final color = income ? Colors.green.shade700 : Colors.red.shade700;
    final title =
        transaction.category ??
        transaction.note ??
        financeTypeLabel(lcm, transaction.type);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            income ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(title)),
            if (transaction.isPrivateForLlm)
              const Icon(Icons.lock_outline, size: 18),
          ],
        ),
        subtitle: Text(
          [
            formatDate(context, transaction.date),
            if (transaction.account != null) transaction.account!,
            if (transaction.note != null && transaction.note != title)
              transaction.note!,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${income ? '+' : '−'}${transaction.amount.toStringAsFixed(2)} '
              '${transaction.currency}',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: color),
            ),
            PopupMenuButton<String>(
              tooltip: lcm.actionDelete,
              onSelected: (_) => onDelete(),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'delete', child: Text(lcm.actionDelete)),
              ],
            ),
          ],
        ),
        onLongPress: onDelete,
      ),
    );
  }
}

class _FinanceEditorDialog extends StatefulWidget {
  const _FinanceEditorDialog({required this.transaction});

  final FinanceTransaction? transaction;

  @override
  State<_FinanceEditorDialog> createState() => _FinanceEditorDialogState();
}

class _FinanceEditorDialogState extends State<_FinanceEditorDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _currency;
  late final TextEditingController _category;
  late final TextEditingController _account;
  late final TextEditingController _note;
  late FinanceTransactionType _type;
  late DateTime _date;
  late bool _isPrivate;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.transaction?.amount.toString() ?? '',
    );
    _currency = TextEditingController(
      text: widget.transaction?.currency ?? 'RUB',
    );
    _category = TextEditingController(text: widget.transaction?.category ?? '');
    _account = TextEditingController(text: widget.transaction?.account ?? '');
    _note = TextEditingController(text: widget.transaction?.note ?? '');
    _type = widget.transaction?.type ?? FinanceTransactionType.expense;
    _date = widget.transaction?.date ?? DateTime.now().toUtc();
    _isPrivate = widget.transaction?.isPrivateForLlm ?? false;
  }

  @override
  void dispose() {
    _amount.dispose();
    _currency.dispose();
    _category.dispose();
    _account.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, 12).toUtc();
    });
  }

  void _save() {
    final lcm = AppLocalizations.of(context)!;
    final parsed = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      setState(() => _amountError = lcm.errorDetails);
      return;
    }
    Navigator.of(context).pop(
      FinanceDraft(
        amount: parsed,
        type: _type,
        date: _date,
        currency: _currency.text,
        category: _category.text,
        account: _account.text,
        note: _note.text,
        isPrivateForLlm: _isPrivate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.transaction == null ? lcm.actionAdd : lcm.actionEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: dataFieldDecoration(lcm.fieldAmount)
                    .copyWith(errorText: _amountError),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FinanceTransactionType>(
                initialValue: _type,
                decoration: dataFieldDecoration(lcm.fieldType),
                items: [
                  for (final value in FinanceTransactionType.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(financeTypeLabel(lcm, value)),
                    ),
                ],
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currency,
                decoration: dataFieldDecoration(lcm.fieldCurrency),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: dataFieldDecoration(lcm.fieldDate),
                child: Row(
                  children: [
                    Expanded(child: Text(formatDate(context, _date))),
                    IconButton(
                      tooltip: lcm.fieldDate,
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _category,
                decoration: dataFieldDecoration(lcm.fieldCategory),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _account,
                decoration: dataFieldDecoration(lcm.fieldAccount),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: dataFieldDecoration(lcm.fieldNote),
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
        FilledButton(onPressed: _save, child: Text(lcm.actionSave)),
      ],
    );
  }
}
