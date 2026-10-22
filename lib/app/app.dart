import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'desktop_services.dart';
import 'di.dart';
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
      builder: (context, child) =>
          _DesktopLabelsSync(child: child ?? const SizedBox.shrink()),
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

/// Передаёт локализованные подписи в системный трей и заголовок окна.
///
/// Живёт внутри MaterialApp (в builder), поэтому видит [AppLocalizations] и
/// обновляет трей при смене языка без перезапуска (TD-02).
/// На не-Windows платформах ничего не делает.
class _DesktopLabelsSync extends StatefulWidget {
  const _DesktopLabelsSync({required this.child});

  final Widget child;

  @override
  State<_DesktopLabelsSync> createState() => _DesktopLabelsSyncState();
}

class _DesktopLabelsSyncState extends State<_DesktopLabelsSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    final lcm = AppLocalizations.of(context);
    if (lcm == null) return;
    unawaited(
      DesktopServices.setTrayLabels(
        windowTitle: lcm.appTitle,
        tooltip: lcm.appTitle,
        showWindow: lcm.trayMenuShow,
        hideWindow: lcm.trayMenuHide,
        quit: lcm.trayMenuQuit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
