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
final class _AppDatabaseV7 extends AppDatabase {
  _AppDatabaseV7(super.executor);

  @override
  int get schemaVersion => 7;
}

/// База, которая «не понимает» файл v5: нужна для проверки downgrade.
final class _AppDatabaseV3 extends AppDatabase {
  _AppDatabaseV3(super.executor);

  @override
  int get schemaVersion => 3;
}

/// Интеграционные тесты миграций drift.
void main() {
  group('AppDatabase схема v6', () {
    test('schemaVersion = 6 (ядро, напоминания, LLM-слой и аудит)', () {
      final db = InMemoryDbFactory.open();
      addTearDown(db.close);
      expect(db.schemaVersion, 6);
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
      expect(await db.select(db.llmProviderConfigs).get(), isEmpty);
      expect(await db.select(db.chatThreads).get(), isEmpty);
      expect(await db.select(db.chatMessages).get(), isEmpty);

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

        final v5 = AppDatabase(NativeDatabase(file));
        await v5
            .into(v5.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                key: 'keep.me',
                value: 'v5',
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v5.close();

        final v6 = _AppDatabaseV7(NativeDatabase(file));
        addTearDown(() async {
          try {
            await v6.close();
          } on Object {
            // Соединение могло остаться в незавершённой миграции.
          }
        });

        await expectLater(
          () => v6.select(v6.appSettings).get(),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });

  group('Миграция v1 → v5', () {
    test('сохраняет app_settings и создаёт таблицы ядра + FTS + LLM', () async {
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
      expect(db.schemaVersion, 6);
      expect(await db.select(db.llmProviderConfigs).get(), isEmpty);
      expect(await db.select(db.chatThreads).get(), isEmpty);
      expect(await db.select(db.chatMessages).get(), isEmpty);
    });
  });

  group('Защита миграций (R02-004)', () {
    test(
      'v2 → v7 падает до DDL и не оставляет файл в промежуточном виде',
      () async {
        final dir = await Directory.systemTemp.createTemp('second_brain_db_');
        addTearDown(() async {
          if (dir.existsSync()) await dir.delete(recursive: true);
        });
        final file = File('${dir.path}/v2_to_v7.sqlite');
        await _seedV2(file);

        final v6 = _AppDatabaseV7(NativeDatabase(file));
        await expectLater(
          () => v6.select(v6.appSettings).get(),
          throwsA(isA<UnsupportedError>()),
        );
        try {
          await v6.close();
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

        // Файл должен остаться пригодным для штатной миграции v2 → v6.
        final recovered = AppDatabase(NativeDatabase(file));
        addTearDown(recovered.close);
        final task = await recovered.select(recovered.tasks).getSingle();
        expect(task.reminderSentAt, isNull);
        expect(await recovered.select(recovered.chatThreads).get(), isEmpty);
      },
    );

    test('v4 → v3 падает и не перезаписывает user_version', () async {
      // Проверяем политику downgrade: любая версия выше целевой запрещена.
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

      final db = _AppDatabaseV3(NativeDatabase(file));
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

  group('Миграция v2 → v5', () {
    test(
      'добавляет reminder_sent_at, таблицы LLM и сохраняет задачи',
      () async {
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
        expect(db.schemaVersion, 6);

        final task = await db.select(db.tasks).getSingle();
        expect(task.title, 'Напоминание после миграции');
        expect(task.reminderSentAt, isNull);
        expect(task.remindAt?.toUtc(), DateTime.utc(2026, 2, 1, 10));
        expect(await db.select(db.llmProviderConfigs).get(), isEmpty);

        final index = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_tasks_remind'",
            )
            .getSingleOrNull();
        expect(index, isNotNull);
      },
    );
  });

  group('Миграция v4 → v5', () {
    test('добавляет embedding-модель, privacy-флаг и чинит default', () async {
      final dir = await Directory.systemTemp.createTemp('second_brain_db_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/v4.sqlite');

      final now = DateTime.utc(2026, 1, 1);
      final seed = AppDatabase(NativeDatabase(file));
      final firstConfig = await seed
          .into(seed.llmProviderConfigs)
          .insert(
            LlmProviderConfigsCompanion.insert(
              providerType: 'openai',
              displayName: 'First',
              baseUrl: 'https://api.test/v1',
              model: 'first',
              embeddingModel: const Value('embed-first'),
              secretRef: 'llm.api_key.v4.first',
              isDefault: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await seed
          .into(seed.llmProviderConfigs)
          .insert(
            LlmProviderConfigsCompanion.insert(
              providerType: 'anthropic',
              displayName: 'Second',
              baseUrl: 'https://api.anthropic.com/v1',
              model: 'second',
              embeddingModel: const Value('embed-second'),
              secretRef: 'llm.api_key.v4.second',
              isDefault: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final threadId = await seed
          .into(seed.chatThreads)
          .insert(
            ChatThreadsCompanion.insert(
              title: 'V4 thread',
              providerConfigId: Value(firstConfig),
              model: 'first',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await seed
          .into(seed.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              threadId: threadId,
              role: 'user',
              content: 'saved in v4',
              isPrivateForLlm: const Value(true),
              createdAt: now,
            ),
          );

      // Откатываем структуру к v4: колонок v5 ещё нет, default не уникален.
      await seed.customStatement(
        'DROP INDEX IF EXISTS idx_llm_configs_default',
      );
      await seed.customStatement(
        'ALTER TABLE llm_provider_configs DROP COLUMN embedding_model',
      );
      await seed.customStatement(
        'ALTER TABLE chat_messages DROP COLUMN is_private_for_llm',
      );
      await seed.customStatement(
        'CREATE INDEX idx_llm_configs_default '
        'ON llm_provider_configs(is_default)',
      );
      await seed.customStatement(
        'UPDATE llm_provider_configs SET is_default = 1',
      );
      await seed.customStatement('PRAGMA user_version = 4');
      await seed.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.schemaVersion, 6);

      final configColumns = await db
          .customSelect('PRAGMA table_info(llm_provider_configs)')
          .get();
      expect(
        configColumns.map((row) => row.data['name']),
        contains('embedding_model'),
      );
      final messageColumns = await db
          .customSelect('PRAGMA table_info(chat_messages)')
          .get();
      expect(
        messageColumns.map((row) => row.data['name']),
        contains('is_private_for_llm'),
      );

      final configs = await db.select(db.llmProviderConfigs).get();
      expect(configs, hasLength(2));
      expect(configs.where((row) => row.isDefault), hasLength(1));
      expect(configs.every((row) => row.embeddingModel == null), isTrue);

      final message = await db.select(db.chatMessages).getSingle();
      expect(message.content, 'saved in v4');
      expect(message.isPrivateForLlm, isFalse);

      final index = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_llm_configs_default'",
          )
          .getSingle();
      expect(index.data['sql'], contains('UNIQUE'));
      expect(index.data['sql'], contains('WHERE is_default = 1'));

      await expectLater(
        () => db.customStatement(
          'UPDATE llm_provider_configs SET is_default = 1',
        ),
        throwsA(anything),
      );
    });
  });

  group('Миграция v5 → v6', () {
    test('создаёт tool_audit_log и сохраняет существующие данные', () async {
      final dir = await Directory.systemTemp.createTemp('second_brain_db_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/v5.sqlite');

      final seed = AppDatabase(NativeDatabase(file));
      await seed
          .into(seed.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'keep.me',
              value: 'v5',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await seed.customStatement('DROP INDEX IF EXISTS idx_tool_audit_created');
      await seed.customStatement('DROP TABLE tool_audit_log');
      await seed.customStatement('PRAGMA user_version = 5');
      await seed.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final setting = await (db.select(
        db.appSettings,
      )..where((t) => t.key.equals('keep.me'))).getSingle();
      expect(setting.value, 'v5');

      await db
          .into(db.toolAuditEntries)
          .insert(
            ToolAuditEntriesCompanion.insert(
              toolName: 'create_task',
              status: 'ok',
              createdAt: DateTime.utc(2026, 10, 29),
            ),
          );
      final rows = await db.select(db.toolAuditEntries).get();
      expect(rows, hasLength(1));
      expect(rows.single.argumentNames, '');

      final index = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_tool_audit_created'",
          )
          .getSingleOrNull();
      expect(
        index,
        isNotNull,
        reason: 'миграция должна создавать индекс аудита',
      );
    });
  });

  group('Миграция v3 → v5', () {
    test('создаёт LLM-таблицы и сохраняет задачи', () async {
      final dir = await Directory.systemTemp.createTemp('second_brain_db_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/v3.sqlite');

      final seed = AppDatabase(NativeDatabase(file));
      await seed
          .into(seed.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'До LLM-слоя',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await seed.customStatement('DROP TABLE IF EXISTS chat_messages');
      await seed.customStatement('DROP TABLE IF EXISTS chat_threads');
      await seed.customStatement('DROP TABLE IF EXISTS llm_provider_configs');
      await seed.customStatement(
        'DROP INDEX IF EXISTS idx_chat_threads_updated',
      );
      await seed.customStatement(
        'DROP INDEX IF EXISTS idx_chat_messages_thread',
      );
      await seed.customStatement(
        'DROP INDEX IF EXISTS idx_llm_configs_default',
      );
      await seed.customStatement('PRAGMA user_version = 3');
      await seed.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.schemaVersion, 6);
      expect((await db.select(db.tasks).getSingle()).title, 'До LLM-слоя');
      expect(await db.select(db.llmProviderConfigs).get(), isEmpty);
      expect(await db.select(db.chatThreads).get(), isEmpty);
      expect(await db.select(db.chatMessages).get(), isEmpty);
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
