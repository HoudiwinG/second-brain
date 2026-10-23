import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
final class _AppDatabaseV4 extends AppDatabase {
  _AppDatabaseV4(super.executor);

  @override
  int get schemaVersion => 4;
}

/// Интеграционные тесты миграций drift.
void main() {
  group('AppDatabase схема v3', () {
    test('schemaVersion = 3 (ядро данных stage-01 + напоминания)', () {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);
      expect(db.schemaVersion, 3);
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

        final v3 = AppDatabase(NativeDatabase(file));
        await v3
            .into(v3.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                key: 'keep.me',
                value: 'v3',
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v3.close();

        final v4 = _AppDatabaseV4(NativeDatabase(file));
        addTearDown(() async {
          try {
            await v4.close();
          } on Object {
            // Соединение могло остаться в незавершённой миграции.
          }
        });

        await expectLater(
          () => v4.select(v4.appSettings).get(),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });

  group('Миграция v1 → v3', () {
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
      expect(db.schemaVersion, 3);
    });
  });

  group('Защита миграций (R02-004)', () {
    test(
      'v2 → v4 падает до DDL и не оставляет файл в промежуточном виде',
      () async {
        final dir = await Directory.systemTemp.createTemp('second_brain_db_');
        addTearDown(() async {
          if (dir.existsSync()) await dir.delete(recursive: true);
        });
        final file = File('${dir.path}/v2_to_v4.sqlite');
        await _seedV2(file);

        final v4 = _AppDatabaseV4(NativeDatabase(file));
        await expectLater(
          () => v4.select(v4.appSettings).get(),
          throwsA(isA<UnsupportedError>()),
        );
        try {
          await v4.close();
        } on Object {
          // Соединение могло остаться в незавершённой миграции.
        }

        final raw = sqlite.sqlite3.open(file.path);
        final columns = raw
            .select('PRAGMA table_info(tasks)')
            .map((row) => row['name'])
            .toList();
        final version = raw.userVersion;
        raw.close();

        expect(columns, isNot(contains('reminder_sent_at')));
        expect(version, 2);

        // Файл должен остаться пригодным для штатной миграции v2 → v3.
        final recovered = AppDatabase(NativeDatabase(file));
        addTearDown(recovered.close);
        final task = await recovered.select(recovered.tasks).getSingle();
        expect(task.reminderSentAt, isNull);
      },
    );

    test('v4 → v3 падает и не перезаписывает user_version', () async {
      final dir = await Directory.systemTemp.createTemp('second_brain_db_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/v4_to_v3.sqlite');

      final seed = AppDatabase(NativeDatabase(file));
      await seed
          .into(seed.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'keep.me',
              value: 'v3',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await seed.close();

      final raw = sqlite.sqlite3.open(file.path);
      raw.userVersion = 4;
      raw.close();

      final db = AppDatabase(NativeDatabase(file));
      await expectLater(
        () => db.select(db.appSettings).get(),
        throwsA(isA<UnsupportedError>()),
      );
      try {
        await db.close();
      } on Object {
        // Соединение могло остаться в незавершённой миграции.
      }

      final check = sqlite.sqlite3.open(file.path);
      expect(check.userVersion, 4);
      expect(
        check.select('SELECT value FROM app_settings WHERE key = ?', [
          'keep.me',
        ]).single['value'],
        'v3',
      );
      check.close();
    });
  });

  group('Миграция v2 → v3', () {
    test('добавляет reminder_sent_at и сохраняет задачи', () async {
      final dir = await Directory.systemTemp.createTemp('second_brain_db_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/v2.sqlite');

      // Готовим полноценную БД, затем откатываем её до схемы v2:
      // удаляем новую колонку и индекс и выставляем user_version = 2.
      final seed = AppDatabase(NativeDatabase(file));
      await seed
          .into(seed.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Напоминание после миграции',
              remindAt: Value(DateTime.utc(2026, 2, 1, 10)),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await seed.customStatement('DROP INDEX IF EXISTS idx_tasks_remind');
      await seed.customStatement(
        'ALTER TABLE tasks DROP COLUMN reminder_sent_at',
      );
      await seed.customStatement('PRAGMA user_version = 2');
      await seed.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.schemaVersion, 3);

      final task = await db.select(db.tasks).getSingle();
      expect(task.title, 'Напоминание после миграции');
      expect(task.reminderSentAt, isNull);
      expect(task.remindAt?.toUtc(), DateTime.utc(2026, 2, 1, 10));

      final index = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_tasks_remind'",
          )
          .getSingleOrNull();
      expect(index, isNotNull);
    });
  });
}

/// Готовит файл схемы v2: задачи уже есть, `reminder_sent_at` и его индекс
/// отсутствуют, `user_version = 2`.
Future<void> _seedV2(File file) async {
  final seed = AppDatabase(NativeDatabase(file));
  await seed
      .into(seed.tasks)
      .insert(
        TasksCompanion.insert(
          title: 'Напоминание после миграции',
          remindAt: Value(DateTime.utc(2026, 2, 1, 10)),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  await seed.customStatement('DROP INDEX IF EXISTS idx_tasks_remind');
  await seed.customStatement('ALTER TABLE tasks DROP COLUMN reminder_sent_at');
  await seed.customStatement('PRAGMA user_version = 2');
  await seed.close();
}
