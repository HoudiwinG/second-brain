import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/desktop_services.dart';
import 'core/crash/app_crash_reporter.dart';
import 'core/logging/app_logger.dart';

/// Точка входа «Second Brain + AI Assistant» (этап 0 — каркас).
Future<void> main() async {
  Future<void> runAppInternal() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppLogger.init();
    AppCrashReporter.init();

    if (!kIsWeb && Platform.isWindows) {
      await DesktopServices.init();
    }

    AppLogger.i('Second Brain: запуск приложения (этап 0 — каркас)');
    runApp(const ProviderScope(child: SecondBrainApp()));
  }

  await AppCrashReporter.run(runAppInternal);
}
