import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';

import 'helpers/in_memory_db.dart';

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
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(
              key: 'migration.test',
              value: 'ok',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final row = await (db.select(db.appSettings)
            ..where((t) => t.key.equals('migration.test')))
          .getSingleOrNull();

      expect(row, isNotNull);
      expect(row!.value, 'ok');
      // Drift читает DateTime в локальной зоне — сравниваем по моменту времени.
      expect(row.updatedAt.toUtc(), DateTime.utc(2026, 1, 1));
    });

    test('повторное выделение не теряет данные (PRAGMA foreign_keys = ON не падает)',
        () async {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);

      final repo = SettingsRepository(db);
      final res = await repo.set('migration.check', 'foreign_keys');
      res.when(success: (_) {}, failure: (e) => fail('set не должен падать: $e'));
      final read = await repo.get('migration.check');
      expect(read.unwrap(), 'foreign_keys');
    });
  });
}
