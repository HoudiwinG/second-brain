import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

/// Заготовка под crash-reporting (Sentry подключается на поздних этапах).
///
/// Сейчас: перехват синхронных (Flutter) и асинхронных (PlatformDispatcher)
/// ошибок + запуск тела приложения в защищённой зоне. Контракт: [run]
/// гарантирует, что UncaughtException не «умолчит» — каждая ошибка попадает
/// в лог (TD-09).
abstract final class AppCrashReporter {
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      AppLogger.e(
        'FlutterError: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
      // Сохраняем стандартное поведение (печать в консоль в debug).
      previousFlutterOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e('Необработанная асинхронная ошибка', error, stack);
      // true — ошибка уже залогирована, повторный проброс не нужен.
      return true;
    };

    AppLogger.d(
      'AppCrashReporter: инициализирован (локальный режим; внешний reporter — поздние этапы)',
    );
  }

  /// Запускает [body], логируя любые ошибки (включая асинхронные),
  /// чтобы UncaughtException не «умолчал». На поздних этапах сюда
  /// добавится отправка в Sentry/crash-сервер.
  static Future<void> run(FutureOr<void> Function() body) async {
    try {
      await body();
    } catch (error, stack) {
      AppLogger.e('Необработанная ошибка приложения', error, stack);
      rethrow;
    }
  }
}
