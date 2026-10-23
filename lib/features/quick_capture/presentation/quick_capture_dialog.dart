import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../core/result/result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../finance/domain/finance_transaction.dart';
import '../../ideas/domain/idea_entry.dart';
import '../../notes/domain/note.dart';
import '../../tasks/domain/task_item.dart';

/// Тип записи, создаваемой через быстрый ввод.
enum QuickCaptureKind { note, task, idea, finance }

/// Открывает диалог быстрого создания записи.
///
/// Возвращает true, если запись сохранена. Вызывающий экран сам решает,
/// обновлять ли список и показывать ли подтверждение.
Future<bool?> showQuickCaptureDialog(
  BuildContext context, {
  QuickCaptureKind initialKind = QuickCaptureKind.note,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => QuickCaptureDialog(initialKind: initialKind),
  );
}

/// Компактный диалог быстрого ввода: заметка, задача, идея или операция.
class QuickCaptureDialog extends ConsumerStatefulWidget {
  const QuickCaptureDialog({
    super.key,
    this.initialKind = QuickCaptureKind.note,
  });

  final QuickCaptureKind initialKind;

  @override
  ConsumerState<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends ConsumerState<QuickCaptureDialog> {
  late QuickCaptureKind _kind;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  late final TextEditingController _amount;
  late final TextEditingController _category;
  late final TextEditingController _note;
  late FinanceTransactionType _financeType;
  late DateTime _date;
  DateTime? _dueAt;
  var _isPrivate = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _title = TextEditingController();
    _body = TextEditingController();
    _tags = TextEditingController();
    _amount = TextEditingController();
    _category = TextEditingController();
    _note = TextEditingController();
    _financeType = FinanceTransactionType.expense;
    _date = DateTime.now().toUtc();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool finance}) async {
    final initial = finance ? _date.toLocal() : (_dueAt?.toLocal() ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final value = DateTime(picked.year, picked.month, picked.day, 12).toUtc();
    setState(() {
      if (finance) {
        _date = value;
      } else {
        _dueAt = value;
      }
    });
  }

  Future<void> _save() async {
    final lcm = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });

    Result<Object?> result;
    switch (_kind) {
      case QuickCaptureKind.note:
        final title = _title.text.trim().isNotEmpty
            ? _title.text.trim()
            : _body.text.trim().split('\n').first.trim();
        if (title.isEmpty) {
          _required(lcm);
          return;
        }
        final repo = await ref.read(notesRepositoryProvider.future);
        result = await repo.create(
          NoteDraft(
            title: title,
            body: _body.text,
            tags: parseTags(_tags.text),
            isPrivateForLlm: _isPrivate,
          ),
        );
      case QuickCaptureKind.task:
        final title = _title.text.trim();
        if (title.isEmpty) {
          _required(lcm);
          return;
        }
        final repo = await ref.read(tasksRepositoryProvider.future);
        result = await repo.create(
          TaskDraft(
            title: title,
            description: _body.text,
            dueAt: _dueAt,
            tags: parseTags(_tags.text),
            isPrivateForLlm: _isPrivate,
          ),
        );
      case QuickCaptureKind.idea:
        final text = _body.text.trim();
        if (text.isEmpty) {
          _required(lcm);
          return;
        }
        final repo = await ref.read(ideasRepositoryProvider.future);
        result = await repo.create(
          IdeaDraft(
            text: text,
            tags: parseTags(_tags.text),
            isPrivateForLlm: _isPrivate,
          ),
        );
      case QuickCaptureKind.finance:
        final amount = double.tryParse(
          _amount.text.trim().replaceAll(',', '.'),
        );
        if (amount == null || amount <= 0) {
          _required(lcm);
          return;
        }
        final repo = await ref.read(financeRepositoryProvider.future);
        result = await repo.create(
          FinanceDraft(
            amount: amount,
            type: _financeType,
            date: _date,
            category: _category.text,
            note: _note.text,
            isPrivateForLlm: _isPrivate,
          ),
        );
    }

    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (error) {
        setState(() {
          _saving = false;
          _error = '${lcm.errorDetails}: ${error.message}';
        });
      },
    );
  }

  void _required(AppLocalizations lcm) {
    setState(() {
      _saving = false;
      _error = lcm.quickCaptureRequired;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.quickCaptureTitle),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<QuickCaptureKind>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: QuickCaptureKind.note,
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    label: Text(lcm.quickCaptureNote),
                  ),
                  ButtonSegment(
                    value: QuickCaptureKind.task,
                    icon: const Icon(Icons.checklist_outlined),
                    label: Text(lcm.quickCaptureTask),
                  ),
                  ButtonSegment(
                    value: QuickCaptureKind.idea,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text(lcm.quickCaptureIdea),
                  ),
                  ButtonSegment(
                    value: QuickCaptureKind.finance,
                    icon: const Icon(Icons.savings_outlined),
                    label: Text(lcm.quickCaptureFinance),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _kind = selection.first;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 16),
              ..._fields(lcm),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                lcm.quickCaptureHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(lcm.actionSave),
        ),
      ],
    );
  }

  List<Widget> _fields(AppLocalizations lcm) {
    switch (_kind) {
      case QuickCaptureKind.note:
        return [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: dataFieldDecoration(lcm.fieldTitle),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            decoration: dataFieldDecoration(lcm.fieldBody),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: dataFieldDecoration(lcm.fieldTags),
          ),
          _privateSwitch(lcm),
        ];
      case QuickCaptureKind.task:
        return [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: dataFieldDecoration(lcm.fieldTitle),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 5,
            decoration: dataFieldDecoration(lcm.fieldDescription),
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
                  onPressed: () => _pickDate(finance: false),
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
          _privateSwitch(lcm),
        ];
      case QuickCaptureKind.idea:
        return [
          TextField(
            controller: _body,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            decoration: dataFieldDecoration(lcm.fieldIdeaText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: dataFieldDecoration(lcm.fieldTags),
          ),
          _privateSwitch(lcm),
        ];
      case QuickCaptureKind.finance:
        return [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: dataFieldDecoration(lcm.fieldAmount),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FinanceTransactionType>(
            initialValue: _financeType,
            decoration: dataFieldDecoration(lcm.fieldType),
            items: [
              for (final value in FinanceTransactionType.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(financeTypeLabel(lcm, value)),
                ),
            ],
            onChanged: (value) =>
                setState(() => _financeType = value ?? _financeType),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: dataFieldDecoration(lcm.fieldDate),
            child: Row(
              children: [
                Expanded(child: Text(formatDate(context, _date))),
                IconButton(
                  tooltip: lcm.fieldDate,
                  onPressed: () => _pickDate(finance: true),
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
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: dataFieldDecoration(lcm.fieldNote),
          ),
          _privateSwitch(lcm),
        ];
    }
  }

  Widget _privateSwitch(AppLocalizations lcm) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(lcm.fieldPrivate),
    value: _isPrivate,
    onChanged: _saving
        ? null
        : (value) => setState(() => _isPrivate = value),
  );
}
