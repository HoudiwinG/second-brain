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

  /// Отдельная модель embeddings; null — умолчание типа провайдера.
  TextColumn get embeddingModel => text().nullable()();

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

/// Сообщение чата.
///
/// Завершённый ответ сохраняется целиком; при отмене — уже полученный
/// фрагмент. Ошибка после partial-ответа сохраняет текст вместе с
/// `error_code = 'llm_error'`, чтобы он не попал в следующий контекст.
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get threadId =>
      integer().references(ChatThreads, #id, onDelete: KeyAction.cascade)();

  /// user | assistant | system.
  TextColumn get role => text()();

  TextColumn get content => text()();

  IntColumn get promptTokens => integer().nullable()();

  IntColumn get completionTokens => integer().nullable()();

  /// Код ошибки провайдера (без текста ответа и секретов).
  TextColumn get errorCode => text().nullable()();

  /// true — сообщение исключается из контекста следующих LLM-запросов.
  BoolColumn get isPrivateForLlm =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}

/// Аудит вызовов инструментов ассистента (stage-04).
///
/// Хранит только имена аргументов и id сущности: значения (заголовки, тексты)
/// не пишутся, чтобы аудит не стал копией приватного содержимого.
class ToolAuditEntries extends Table {
  @override
  String get tableName => 'tool_audit_log';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get toolName => text().withLength(min: 1, max: 100)();

  /// ok | error | unknown_tool | invalid_args.
  TextColumn get status => text().withLength(min: 1, max: 40)();

  /// Имена аргументов через запятую, без значений.
  TextColumn get argumentNames => text().withDefault(const Constant(''))();

  IntColumn get entityId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// Локальная БД SQLite (Drift).
///
/// Схема v6 — ядро данных stage-01 + напоминания stage-02 + LLM-слой stage-03
/// с исправлениями ревью (embedding-модель, приватность сообщений,
/// единственный default-провайдер) + аудит инструментов stage-04.
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
    ToolAuditEntries,
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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      AppLogger.d('AppDatabase: onCreate → создаём схему v$schemaVersion');
      await m.createAll();
      await _createSearchSchema();
      await _createIndexes();
      await _createAuditIndexes();
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
      if (from > to || from > 6 || to > 6) {
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
        // createTable создаёт текущую структуру таблиц (уже с колонками v5).
        await m.createTable(llmProviderConfigs);
        await m.createTable(chatThreads);
        await m.createTable(chatMessages);
      } else if (from < 5) {
        // v5: отдельная embedding-модель и приватность сообщений.
        await m.addColumn(
          llmProviderConfigs,
          llmProviderConfigs.embeddingModel,
        );
        await m.addColumn(chatMessages, chatMessages.isPrivateForLlm);
      }
      if (from < 5) {
        // Инвариант «ровно один default»: чиним возможные 0/2 default
        // до создания unique partial index.
        await _normalizeDefaultConfigs();
        await _createIndexes();
      }
      if (from < 6) {
        // v6: аудит вызовов инструментов ассистента.
        await m.createTable(toolAuditEntries);
        await _createAuditIndexes();
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
      'ON chat_messages(thread_id, created_at, id)',
    );
    // Partial unique index гарантирует не больше одного default на уровне БД.
    await customStatement('DROP INDEX IF EXISTS idx_llm_configs_default');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_llm_configs_default '
      'ON llm_provider_configs(is_default) WHERE is_default = 1',
    );
  }

  /// Индекс аудита создаётся после таблицы `tool_audit_log` (v6).
  Future<void> _createAuditIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tool_audit_created '
      'ON tool_audit_log(created_at)',
    );
  }

  /// Оставляет максимум один default и назначает его, если есть конфигурации.
  Future<void> _normalizeDefaultConfigs() async {
    await customStatement('UPDATE llm_provider_configs SET is_default = 0');
    await customStatement('''
      UPDATE llm_provider_configs SET is_default = 1
      WHERE id = (
        SELECT id FROM llm_provider_configs
        ORDER BY updated_at DESC, id ASC
        LIMIT 1
      )
    ''');
  }
}
