import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/settings_controller.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Экран настроек (этап 0): переключатели темы и языка.
///
/// Полный набор настроек (LLM-ключи, приватность, интеграции, экспорт)
/// появится на следующих этапах.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lcm = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(lcm.settingsTitle)),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${lcm.errorUnexpected}: $e')),
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(lcm.settingsAppearance, style: Theme.of(context).textTheme.titleMedium),
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
              onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
            ),
            const SizedBox(height: 24),
            Text(lcm.settingsLanguageSection, style: Theme.of(context).textTheme.titleMedium),
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
                ButtonSegment(
                  value: 'ru',
                  label: Text(lcm.settingsLanguageRu),
                ),
                ButtonSegment(
                  value: 'en',
                  label: Text(lcm.settingsLanguageEn),
                ),
              ],
              selected: {
                state.locale?.languageCode ?? SettingsController.localeSystem,
              },
              onSelectionChanged: (selection) {
                final raw = selection.first;
                controller.setLocale(
                  raw == SettingsController.localeSystem ? null : Locale(raw),
                );
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(lcm.hintGlobalHotkey, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
