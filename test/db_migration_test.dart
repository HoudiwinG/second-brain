import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';

import 'helpers/in_memory_db.dart';

/// Тестовая «следующая» версия схемы без миграции.
///
/// Нужна, чтобы проверить политику ADR-012: непокрытый переход onUpgrade
/// обязан падать, а не молча создавать недостающие таблицы.
final class _AppDatabaseV2 extends AppDatabase {
  _AppDatabaseV2(super.executor);

  @override
  int get schemaVersion => 2;
}

/// Интеграционный тест миграций drift: схема создаётся с нуля
/// (onCreate → v1), таблица app_settings доступна сразу.
void main() {
  group('AppDatabase миграции', () {
    test('schemaVersion = 1 (первая версия схемы)', () {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);
      expect(db.schemaVersion, 1);
    });

    test('onCreate создаёт таблицу app_settings: запись и чтение работают', () async {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);

      // Прямая вставка подтверждает, что таблица создана миграцией.
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'migration.test',
              value: 'ok',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final row = await (db.select(
        db.appSettings,
      )..where((t) => t.key.equals('migration.test'))).getSingleOrNull();

      expect(row, isNotNull);
      expect(row!.value, 'ok');
      // Drift читает DateTime в локальной зоне — сравниваем по моменту времени.
      expect(row.updatedAt.toUtc(), DateTime.utc(2026, 1, 1));
    });

    test('set/get сохраняет значение поверх onCreate', () async {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);

      final repo = SettingsRepository(db);
      final res = await repo.set('migration.check', 'foreign_keys');
      res.when(
        success: (_) {},
        failure: (e) => fail('set не должен падать: $e'),
      );
      final read = await repo.get('migration.check');
      expect(read.unwrap(), 'foreign_keys');
    });

    test('beforeOpen включает PRAGMA foreign_keys', () async {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);

      // customSelect инициирует открытие БД → beforeOpen.
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });

    test(
      'onUpgrade неизвестной версии падает UnsupportedError (ADR-012)',
      () async {
        final dir = await Directory.systemTemp.createTemp('second_brain_db_');
        addTearDown(() async {
          if (dir.existsSync()) await dir.delete(recursive: true);
        });
        final file = File('${dir.path}/migration.sqlite');

        // Создаём файловую БД версии 1 и оставляем данные.
        final v1 = AppDatabase(NativeDatabase(file));
        await v1
            .into(v1.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                key: 'keep.me',
                value: 'v1',
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v1.close();

        // Открываем её «новой» версией без миграции: onUpgrade обязан упасть.
        final v2 = _AppDatabaseV2(NativeDatabase(file));
        addTearDown(() async {
          try {
            await v2.close();
          } on Object {
            // Соединение могло остаться в незавершённой миграции.
          }
        });

        await expectLater(
          () => v2.select(v2.appSettings).get(),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });
}
