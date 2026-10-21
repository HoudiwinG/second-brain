import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../db/app_database.dart';

/// Символьные ключи настроек, используемые на этапе 0.
abstract final class SettingsKeys {
  /// Режим темы: system | light | dark.
  static const String themeMode = 'theme.mode';

  /// Код языка интерфейса: system | ru | en.
  static const String language = 'language.code';
}

/// Типизированный доступ к key-value настройкам (таблица app_settings).
///
/// Все обращения возвращают [Result], чтобы UI не зависел от исключений drift.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// Читает значение по ключу; null, если настройки нет.
  Future<Result<String?>> get(String key) async {
    try {
      final row = await (_db.select(_db.appSettings)..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      return Result.success(row?.value);
    } on Exception catch (e, s) {
      return Result.failure(
        DataException('SettingsRepository: чтение "$key"', cause: e, stackTrace: s),
      );
    }
  }

  /// Возвращает значение или [fallback], если настройка не задана.
  Future<Result<String>> getOrDefault(String key, String fallback) async {
    final res = await get(key);
    return res.when(
      success: (v) => Result.success(v ?? fallback),
      failure: Result.failure,
    );
  }

  /// Вставляет или перезаписывает настройку.
  Future<Result<void>> set(String key, String value) async {
    try {
      final now = DateTime.now().toUtc();
      await _db.into(_db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: key, value: value, updatedAt: now),
          );
      AppLogger.d('SettingsRepository: set "$key" (длина значения ${value.length})');
      return const Result.success(null);
    } on Exception catch (e, s) {
      return Result.failure(
        DataException('SettingsRepository: запись "$key"', cause: e, stackTrace: s),
      );
    }
  }

  /// Удаляет настройку.
  Future<Result<void>> remove(String key) async {
    try {
      await (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
      return const Result.success(null);
    } on Exception catch (e, s) {
      return Result.failure(
        DataException('SettingsRepository: удаление "$key"', cause: e, stackTrace: s),
      );
    }
  }

  /// Количество записей (используется тестами миграций).
  Future<int> count() async {
    final rows = await _db.select(_db.appSettings).get();
    return rows.length;
  }
}
