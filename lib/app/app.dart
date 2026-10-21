import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import 'di.dart';
import 'settings_controller.dart';
import 'theme.dart';

/// Корневой виджет приложения: Riverpod + MaterialApp.router.
///
/// Тема и локаль применяются из [SettingsController] с персистентностью
/// в локальной БД, поэтому выбор пользователя сохраняется между запусками.
class SecondBrainApp extends ConsumerWidget {
  const SecondBrainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider).router;
    final settings = ref.watch(settingsControllerProvider);
    final state = settings.value ?? const SettingsState();

    return MaterialApp.router(
      // onGenerateTitle — потому что локальный delegate доступен
      // только после построения MaterialApp.
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: state.themeMode,
      theme: AppThemes.light(),
      darkTheme: AppThemes.dark(),
      locale: state.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
