import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../app/quick_hotkey.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Диалог записи глобальной комбинации быстрого ввода.
class HotkeyRecorderDialog extends StatefulWidget {
  const HotkeyRecorderDialog({super.key, required this.current});

  final QuickHotkey current;

  @override
  State<HotkeyRecorderDialog> createState() => _HotkeyRecorderDialogState();
}

class _HotkeyRecorderDialogState extends State<HotkeyRecorderDialog> {
  late HotKey _recorded;
  QuickHotkey? _candidate;

  @override
  void initState() {
    super.initState();
    _recorded = widget.current.toHotKey();
    _candidate = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.hotkeyRecorderTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lcm.hotkeyRecorderHint),
            const SizedBox(height: 16),
            Container(
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: HotKeyRecorder(
                initalHotKey: _recorded,
                onHotKeyRecorded: (hotKey) {
                  setState(() {
                    _recorded = hotKey;
                    _candidate = QuickHotkey.fromHotKey(hotKey);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_candidate == null)
              Text(
                lcm.hotkeyRecorderInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              Text(
                _candidate!.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(
          onPressed: _candidate == null
              ? null
              : () => Navigator.of(context).pop(_candidate),
          child: Text(lcm.actionSave),
        ),
      ],
    );
  }
}
