import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/desktop_services.dart';
import 'core/crash/app_crash_reporter.dart';
import 'core/logging/app_logger.dart';
import 'features/reminders/application/reminder_notifier.dart';

/// Точка входа «Second Brain + AI Assistant» (этап 0 — каркас).
Future<void> main() async {
  Future<void> runAppInternal() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppLogger.init();
    AppCrashReporter.init();

    // defaultTargetPlatform вместо dart:io — точка входа остаётся
    // совместимой с web (TD-11). Ошибки desktop-плагинов не должны мешать
    // запуску приложения (TD-03).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await DesktopServices.init();
        await LocalReminderNotifier.initialize();
      } on Exception catch (e, s) {
        AppLogger.e('main: ошибка инициализации desktop-сервисов', e, s);
      }
    }

    AppLogger.i('Second Brain: запуск приложения (этап 0 — каркас)');
    runApp(const ProviderScope(child: SecondBrainApp()));
  }

  await AppCrashReporter.run(runAppInternal);
}
