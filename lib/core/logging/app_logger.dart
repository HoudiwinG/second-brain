import 'package:logger/logger.dart' as pkg;

import '../error/app_exception.dart';

/// Логгер приложения.
///
/// Используется вместо `debugPrint` и `print` во всех слоях.
/// Уровень задаётся при [init] (по умолчанию — debug).
abstract final class AppLogger {
  static pkg.Logger _logger = _create(pkg.Level.debug);

  static pkg.Logger _create(pkg.Level level) => pkg.Logger(
    printer: pkg.PrettyPrinter(
      methodCount: 0,
      lineLength: 120,
      dateTimeFormat: pkg.DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: level,
  );

  /// Инициализация логгера. Уровень настраивается из фича-флагов позже.
  static void init({pkg.Level level = pkg.Level.debug}) {
    _logger = _create(level);
  }

  static void d(String message) => _logger.d(message);

  static void i(String message) => _logger.i(message);

  static void w(String message, [Object? error]) =>
      _logger.w('$message${error == null ? '' : ' | ${_safe(error)}'}');

  static void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(
        '$message${error == null ? '' : ' | ${_safe(error)}'}',
        stackTrace: stackTrace,
      );

  /// Логирование [AppException] без содержимого приватных данных:
  /// печатаем только тип и message, никогда значения сущностей.
  static void appError(AppException e, [StackTrace? stackTrace]) =>
      _logger.e(e.toString(), stackTrace: stackTrace ?? e.stackTrace);

  /// Для неизвестных ошибок печатаем только тип: `toString()` может
  /// содержать тело ответа, фрагмент JSON или значение сущности.
  static String _safe(Object error) =>
      error is AppException ? error.toString() : error.runtimeType.toString();
}
