import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';

part 'app_database.g.dart';

/// Таблица настроек (key-value).
///
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

/// Категории заметок. Иерархия задаётся nullable-ссылкой [parentId].
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  IntColumn get parentId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// Заметки: основной текстовый контент приложения.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  TextColumn get body => text().withDefault(const Constant(''))();

  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// true — содержимое запрещено отправлять во внешнюю LLM.
  BoolColumn get isPrivateForLlm =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Soft-delete: строка остаётся для синхронизации/восстановления.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Справочник тегов (общий для заметок, задач и идей).
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 100).unique()();

  DateTimeColumn get createdAt => dateTime()();
}

/// Связь заметки и тега (many-to-many).
class NoteTags extends Table {
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

/// Задачи и напоминания.
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  TextColumn get description => text().withDefault(const Constant(''))();

  /// low | normal | high | urgent.
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  DateTimeColumn get dueAt => dateTime().nullable()();

  DateTimeColumn get remindAt => dateTime().nullable()();

  /// Время, когда напоминание уже показано пользователю.
  ///
  /// Защищает от повторных системных уведомлений после перезапуска.
  DateTimeColumn get reminderSentAt => dateTime().nullable()();

  /// todo | in_progress | done | cancelled.
  TextColumn get status => text().withDefault(const Constant('todo'))();

  IntColumn get linkedNoteId => integer().nullable().references(
    Notes,
    #id,
    onDelete: KeyAction.setNull,
  )();

  BoolColumn get isPrivateForLlm =>
      boolean().withDefault(const Constant(false))();

  /// Правило повторения в свободной форме (RRULE появится на этапе напоминаний).
  TextColumn get recurrence => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Связь задачи и тега.
class TaskTags extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

/// Дневник идей.
class IdeaEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Содержимое идеи. Имя геттера не `text`, чтобы не перекрывать
  /// Drift-билдер `text()` (иначе drift_dev падает при разборе таблицы).
  TextColumn get content => text()();

  TextColumn get source => text().nullable()();

  TextColumn get mood => text().nullable()();

  BoolColumn get isPrivateForLlm =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Связь идеи и тега.
class IdeaTags extends Table {
  IntColumn get ideaId =>
      integer().references(IdeaEntries, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {ideaId, tagId};
}

/// Финансовая операция (доход/расход).
class FinanceTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  RealColumn get amount => real()();

  TextColumn get currency => text().withDefault(const Constant('RUB'))();

  /// income | expense.
  TextColumn get type => text()();

  TextColumn get category => text().nullable()();

  TextColumn get account => text().nullable()();

  DateTimeColumn get date => dateTime()();

  TextColumn get note => text().nullable()();

  BoolColumn get isPrivateForLlm =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Конфигурация LLM-провайдера.
///
/// Сам API-ключ здесь не хранится: [secretRef] — имя записи в
/// [SecretStore] (secure storage). Это позволяет делать бэкап БД без утечки
/// секретов и не логировать ключи.
class LlmProviderConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// openai | openai_compatible | anthropic | google.
  TextColumn get providerType => text()();

  TextColumn get displayName => text().withLength(min: 1, max: 100)();

  /// Базовый URL API (без завершающего слэша).
  TextColumn get baseUrl => text()();

  TextColumn get model => text().withLength(min: 1, max: 200)();

  /// Жёсткий лимит токенов ответа (защита от больших счетов).
  IntColumn get maxTokens => integer().withDefault(const Constant(1024))();

  /// Имя секрета в secure storage, например `llm.api_key.1`.
  TextColumn get secretRef => text().unique()();

  /// Провайдер по умолчанию для новых чатов.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// Тред чата с LLM. История доступна офлайн.
class ChatThreads extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Конфигурация провайдера на момент создания треда.
  /// Удаление конфигурации не удаляет историю.
  IntColumn get providerConfigId => integer().nullable().references(
    LlmProviderConfigs,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get model => text().withLength(min: 1, max: 200)();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get archivedAt => dateTime().nullable()();
}

/// Сообщение чата. Частичный стриминговый ответ не сохраняется:
/// в БД попадает только завершённое сообщение (или ошибка без контента).
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get threadId => integer().references(
    ChatThreads,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// user | assistant | system.
  TextColumn get role => text()();

  TextColumn get content => text()();

  IntColumn get promptTokens => integer().nullable()();

  IntColumn get completionTokens => integer().nullable()();

  /// Код ошибки провайдера (без текста ответа и секретов).
  TextColumn get errorCode => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// Локальная БД SQLite (Drift).
///
/// Схема v4 — ядро данных stage-01 + напоминания stage-02 + LLM-слой stage-03.
/// Полнотекстовый индекс `search_index`
/// создаётся отдельными SQL-командами: FTS5 — виртуальная таблица, которую
/// Drift не описывает декларативно (ADR-013).
@DriftDatabase(
  tables: [
    AppSettings,
    Categories,
    Notes,
    Tags,
    NoteTags,
    Tasks,
    TaskTags,
    IdeaEntries,
    IdeaTags,
    FinanceTransactions,
    LlmProviderConfigs,
    ChatThreads,
    ChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Фабрика для runtime: файл SQLite в каталоге данных приложения.
  ///
  /// NativeDatabase.createInBackground — запросы не блокируют UI-поток.
  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final db = AppDatabase(
      NativeDatabase.createInBackground(File('${dir.path}/second_brain.db')),
    );
    AppLogger.d('AppDatabase: открыт файл ${dir.path}/second_brain.db');
    return db;
  }

  /// Фабрика для тестов: полностью in-memory.
  static AppDatabase inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      AppLogger.d('AppDatabase: onCreate → создаём схему v$schemaVersion');
      await m.createAll();
      await _createSearchSchema();
      await _createIndexes();
    },
    // ВАЖНО: createAll() в onUpgrade не используется. Он создаёт только
    // отсутствующие таблицы и молча пропускает ALTER/перенос данных,
    // из-за чего новая версия схемы может открыться с неверной структурой.
    // Для каждой новой версии добавляется явная ветка миграции (ADR-012).
    onUpgrade: (Migrator m, int from, int to) async {
      AppLogger.d('AppDatabase: onUpgrade с $from до $to');
      // Проверяем поддержку перехода до любых DDL. Иначе v2 → v4 успевает
      // добавить колонку и индекс, а затем падает, оставляя файл в
      // промежуточном состоянии; downgrade v4 → v3 и вовсе молча
      // перезаписывал user_version (R02-004).
      if (from > to || from > 4 || to > 4) {
        throw UnsupportedError(
          'AppDatabase: нет миграции схемы $from → $to. '
          'Добавьте явную миграцию в onUpgrade (ADR-012).',
        );
      }
      if (from < 2) {
        // Порядок важен: сначала родительские таблицы, затем связи.
        // createTable(tasks) сразу создаёт колонки текущей схемы, поэтому
        // отдельный addColumn для v3 в этой ветке не нужен.
        await m.createTable(categories);
        await m.createTable(tags);
        await m.createTable(notes);
        await m.createTable(noteTags);
        await m.createTable(tasks);
        await m.createTable(taskTags);
        await m.createTable(ideaEntries);
        await m.createTable(ideaTags);
        await m.createTable(financeTransactions);
        await _createSearchSchema();
      } else if (from < 3) {
        // v3: защита от повторных напоминаний после перезапуска.
        await m.addColumn(tasks, tasks.reminderSentAt);
      }
      if (from < 4) {
        // v4: конфигурации LLM и офлайн-история чата.
        // createTable создаёт текущую структуру таблиц; отдельных ALTER нет.
        await m.createTable(llmProviderConfigs);
        await m.createTable(chatThreads);
        await m.createTable(chatMessages);
        await _createIndexes();
      }
    },
    beforeOpen: (details) async {
      AppLogger.d('AppDatabase: beforeOpen (upgrade=${details.hadUpgrade})');
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// FTS5-индекс по заметкам, задачам, идеям и финансам.
  ///
  /// Таблица создаётся идемпотентно: это позволяет безопасно применять
  /// миграцию повторно и использовать её в тестах. Индексы создаются
  /// отдельно, после всех таблиц: в v1 → v4 таблицы LLM появляются позже.
  Future<void> _createSearchSchema() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        entity_type UNINDEXED,
        entity_id UNINDEXED,
        title,
        body,
        tags,
        is_private UNINDEXED,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  }

  /// Индексы для внешних ключей и выборок по датам/soft-delete.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_remind '
      'ON tasks(remind_at, reminder_sent_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ideas_deleted ON idea_entries(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_date ON finance_transactions(date, type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_deleted ON finance_transactions(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chat_threads_updated '
      'ON chat_threads(updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_thread '
      'ON chat_messages(thread_id, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_llm_configs_default '
      'ON llm_provider_configs(is_default)',
    );
  }
}
