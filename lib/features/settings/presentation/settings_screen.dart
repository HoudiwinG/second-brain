import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/di.dart';
import '../../../app/quick_hotkey.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../core/logging/app_logger.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/settings_controller.dart';
import 'hotkey_recorder_dialog.dart';

/// Экран настроек (этап 0): переключатели темы и языка.
///
/// Полный набор настроек (LLM-ключи, приватность, интеграции, экспорт)
/// появится на следующих этапах.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportJson(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
  ) async {
    try {
      final service = await ref.read(backupServiceProvider.future);
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}backups'
        '${Platform.pathSeparator}second-brain-'
        '${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json',
      );
      final result = await service.exportJson(file);
      if (!context.mounted) return;
      result.when(
        success: (_) =>
            showMessageSnackBar(context, '${lcm.exportSuccess}: ${file.path}'),
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.e('SettingsScreen: экспорт JSON не удался', error, stackTrace);
      if (context.mounted) {
        showMessageSnackBar(context, lcm.errorUnexpected);
      }
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
  ) async {
    try {
      final service = await ref.read(backupServiceProvider.future);
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}backups'
        '${Platform.pathSeparator}finance-'
        '${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.csv',
      );
      final result = await service.exportFinanceCsv(file);
      if (!context.mounted) return;
      result.when(
        success: (_) =>
            showMessageSnackBar(context, '${lcm.exportSuccess}: ${file.path}'),
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.e('SettingsScreen: экспорт CSV не удался', error, stackTrace);
      if (context.mounted) {
        showMessageSnackBar(context, lcm.errorUnexpected);
      }
    }
  }

  Future<String?> _askPath(
    BuildContext context,
    AppLocalizations lcm, {
    required String initial,
    required bool showWarning,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(lcm.fieldPath),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showWarning) ...[
                Text(
                  lcm.importWarning,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                decoration: dataFieldDecoration(lcm.fieldPath),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(lcm.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(lcm.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String> _defaultPath(String fileName) async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  Future<void> _importJson(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
  ) async {
    try {
      final initial = await _defaultPath('second-brain-backup.json');
      if (!context.mounted) return;
      final path = await _askPath(
        context,
        lcm,
        initial: initial,
        showWarning: true,
      );
      if (path == null) return;
      final trimmed = path.trim();
      if (trimmed.isEmpty || !context.mounted) return;
      final service = await ref.read(backupServiceProvider.future);
      final result = await service.importJson(File(trimmed));
      if (!context.mounted) return;
      result.when(
        success: (_) => showMessageSnackBar(context, lcm.importSuccess),
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.e('SettingsScreen: импорт JSON не удался', error, stackTrace);
      if (context.mounted) {
        showMessageSnackBar(context, lcm.errorUnexpected);
      }
    }
  }

  Future<void> _importCsv(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
  ) async {
    try {
      final initial = await _defaultPath('finance.csv');
      if (!context.mounted) return;
      final path = await _askPath(
        context,
        lcm,
        initial: initial,
        showWarning: false,
      );
      if (path == null) return;
      final trimmed = path.trim();
      if (trimmed.isEmpty || !context.mounted) return;
      final service = await ref.read(backupServiceProvider.future);
      final result = await service.importFinanceCsv(File(trimmed));
      if (!context.mounted) return;
      result.when(
        success: (_) => showMessageSnackBar(context, lcm.importSuccess),
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.e('SettingsScreen: импорт CSV не удался', error, stackTrace);
      if (context.mounted) {
        showMessageSnackBar(context, lcm.errorUnexpected);
      }
    }
  }

  Future<void> _changeHotkey(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations lcm,
    SettingsState state,
  ) async {
    final selected = await showDialog<QuickHotkey>(
      context: context,
      builder: (dialogContext) =>
          HotkeyRecorderDialog(current: state.quickHotkey),
    );
    if (selected == null || !context.mounted) return;
    final saved = await ref
        .read(settingsControllerProvider.notifier)
        .setQuickHotkey(selected);
    if (!saved && context.mounted) {
      showMessageSnackBar(context, lcm.hotkeyBusyError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lcm = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(lcm.settingsTitle)),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) {
          // Подробности — только в лог: исключение может содержать пути и
          // внутренние детали БД (TD-10).
          AppLogger.e('SettingsScreen: не удалось загрузить настройки', e, s);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lcm.errorUnexpected, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(settingsControllerProvider),
                  child: Text(lcm.retryAction),
                ),
              ],
            ),
          );
        },
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              lcm.settingsAppearance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(lcm.settingsTheme),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(lcm.settingsThemeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(lcm.settingsThemeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(lcm.settingsThemeDark),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (selection) async {
                final saved = await controller.setThemeMode(selection.first);
                if (!saved && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(lcm.errorUnexpected)));
                }
              },
            ),
            const SizedBox(height: 24),
            Text(
              lcm.settingsLanguageSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(lcm.settingsLanguage),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: SettingsController.localeSystem,
                  icon: const Icon(Icons.language),
                  label: Text(lcm.settingsLanguageSystem),
                ),
                ButtonSegment(value: 'ru', label: Text(lcm.settingsLanguageRu)),
                ButtonSegment(value: 'en', label: Text(lcm.settingsLanguageEn)),
              ],
              selected: {
                state.locale?.languageCode ?? SettingsController.localeSystem,
              },
              onSelectionChanged: (selection) async {
                final raw = selection.first;
                final saved = await controller.setLocale(
                  raw == SettingsController.localeSystem ? null : Locale(raw),
                );
                if (!saved && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(lcm.errorUnexpected)));
                }
              },
            ),
            const SizedBox(height: 24),
            Text(
              lcm.settingsHotkeySection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: Text(lcm.settingsQuickCaptureHotkey),
                subtitle: Text(state.quickHotkey.label),
                trailing: OutlinedButton.icon(
                  onPressed: () =>
                      _changeHotkey(context, ref, lcm, state),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(lcm.actionChangeHotkey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lcm.hintGlobalHotkey,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text(
              lcm.dataSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              lcm.settingsDataHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _exportJson(context, ref, lcm),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(lcm.actionExportJson),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportCsv(context, ref, lcm),
                  icon: const Icon(Icons.table_view_outlined),
                  label: Text(lcm.actionExportCsv),
                ),
                OutlinedButton.icon(
                  onPressed: () => _importJson(context, ref, lcm),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(lcm.actionImportJson),
                ),
                OutlinedButton.icon(
                  onPressed: () => _importCsv(context, ref, lcm),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(lcm.actionImportCsv),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
