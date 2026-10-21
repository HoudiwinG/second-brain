import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';

part 'app_database.g.dart';

/// Таблица настроек (key-value).
///
/// Этап 0: единственная таблица, чтобы проверить механизм миграций.
/// Значения хранятся строками; типизация — на уровне репозиториев.
class AppSettings extends Table {
  /// Символьный ключ настройки, например `theme.mode` или `language.code`.
  TextColumn get key => text()();

  /// Значение настройки (строка; семантика определяется ключом).
  TextColumn get value => text()();

  /// Время последнего изменения (UTC).
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Фабрика для runtime: файл SQLite в каталоге данных приложения.
  ///
  /// NativeDatabase.createInBackground — запросы не блокируют UI-поток.
  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final db = AppDatabase(NativeDatabase.createInBackground(File('${dir.path}/second_brain.db')));
    AppLogger.d('AppDatabase: открыт файл ${dir.path}/second_brain.db');
    return db;
  }

  /// Фабрика для тестов: полностью in-memory.
  static AppDatabase inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          AppLogger.d('AppDatabase: onCreate → создаём схему v$schemaVersion');
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          AppLogger.d('AppDatabase: onUpgrade с $from до $to');
          // Пока единственная версия схемы v1; при v1→v2 добавить alterTable.
          await m.createAll();
        },
        beforeOpen: (details) async {
          AppLogger.d('AppDatabase: beforeOpen (upgrade=${details.hadUpgrade})');
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
