import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/search_repository.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'helpers/in_memory_db.dart';

/// Тестовая «следующая» версия схемы без миграции.
///
/// Нужна, чтобы проверить политику ADR-012: непокрытый переход onUpgrade
/// обязан падать, а не молча создавать недостающие таблицы.
final class _AppDatabaseV3 extends AppDatabase {
  _AppDatabaseV3(super.executor);

  @override
  int get schemaVersion => 3;
}

/// Интеграционные тесты миграций drift.
void main() {
  group('AppDatabase схема v2', () {
    test('schemaVersion = 2 (ядро данных stage-01)', () {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);
      expect(db.schemaVersion, 2);
    });

    test('onCreate создаёт app_settings и таблицы ядра', () async {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);

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

      expect(await db.select(db.categories).get(), isEmpty);
      expect(await db.select(db.notes).get(), isEmpty);
      expect(await db.select(db.tasks).get(), isEmpty);
      expect(await db.select(db.ideaEntries).get(), isEmpty);
      expect(await db.select(db.financeTransactions).get(), isEmpty);

      final fts = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'search_index'",
          )
          .getSingleOrNull();
      expect(fts, isNotNull);
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
      'неизвестная будущая версия падает UnsupportedError (ADR-012)',
      () async {
        final dir = await Directory.systemTemp.createTemp('second_brain_db_');
        addTearDown(() async {
          if (dir.existsSync()) await dir.delete(recursive: true);
        });
        final file = File('${dir.path}/migration.sqlite');

        final v2 = AppDatabase(NativeDatabase(file));
        await v2
            .into(v2.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                key: 'keep.me',
                value: 'v2',
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v2.close();

        final v3 = _AppDatabaseV3(NativeDatabase(file));
        addTearDown(() async {
          try {
            await v3.close();
          } on Object {
            // Соединение могло остаться в незавершённой миграции.
          }
        });

        await expectLater(
          () => v3.select(v3.appSettings).get(),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });

  group('Миграция v1 → v2', () {
    test('сохраняет app_settings и создаёт таблицы ядра + FTS', () async {
      final dir = await Directory.systemTemp.createTemp('second_brain_db_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/v1.sqlite');

      // Legacy-файл версии 1: только app_settings, user_version = 1.
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE app_settings (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      legacy.execute(
        'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)',
        [
          'keep.me',
          'v1',
          DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
        ],
      );
      legacy.execute('PRAGMA user_version = 1');
      legacy.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final settings = await (db.select(
        db.appSettings,
      )..where((t) => t.key.equals('keep.me'))).getSingle();
      expect(settings.value, 'v1');
      expect(settings.updatedAt.toUtc(), DateTime.utc(2026, 1, 1));
      expect(await db.select(db.notes).get(), isEmpty);

      final notes = DriftNotesRepository(db);
      final note = (await notes.create(
        const NoteDraft(title: 'После миграции', body: 'FTS работает'),
      )).unwrap();
      final search = DriftSearchRepository(db);
      final hits = (await search.search('миграции')).unwrap();
      expect(hits, hasLength(1));
      expect(hits.single.entityId, note.id);
      expect(db.schemaVersion, 2);
    });
  });
}
