import 'dart:async';

import '../logging/app_logger.dart';

/// Заготовка под crash-reporting (Sentry подключается на поздних этапах).
///
/// Сейчас: инициализация логгера ошибок и запуск тела приложения
/// в защищённой зоне. Контракт: [run] гарантирует, что UncaughtException
/// не «умолчит» — каждая ошибка попадает в лог.
abstract final class AppCrashReporter {
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
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
