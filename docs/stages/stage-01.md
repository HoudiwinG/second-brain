# Stage-01 — Ядро данных

- **Дата:** 2026-10-22
- **Агент:** agent-1 (DeepSeek V4.1 Flash Free, OpenCode)
- **Ветка:** `master`
- **Статус:** **done** (локальные проверки зелёные; CI run 39763804171 — success)
- **Следующий этап:** stage-02 (UX-каркас) по `PROMPT.md`

## Цель этапа

Реализовать локальное ядро данных приложения: заметки, категории, теги,
задачи, дневник идей и финансовые операции с CRUD, полнотекстовым поиском,
флагом приватности для LLM и экспортом/импортом.

## Что реализовано

### Схема БД v2

`lib/data/db/app_database.dart` (+ сгенерированный `app_database.g.dart`):

| Таблица | Назначение | Ключевые поля |
|---------|------------|----------------|
| `app_settings` | настройки key-value | `key` (PK), `value`, `updated_at` |
| `categories` | иерархия категорий заметок | `id`, `name`, `parent_id`, timestamps |
| `notes` | заметки | `title`, `body`, `category_id`, `is_private_for_llm`, `deleted_at` |
| `tags` | общий справочник тегов | `id`, `name` (unique) |
| `note_tags` | M:N заметок и тегов | `note_id`, `tag_id` (PK) |
| `tasks` | задачи | `title`, `description`, `priority`, `status`, `due_at`, `remind_at`, `linked_note_id`, `recurrence`, `is_private_for_llm`, `deleted_at` |
| `task_tags` | M:N задач и тегов | `task_id`, `tag_id` (PK) |
| `idea_entries` | дневник идей | `content`, `source`, `mood`, `is_private_for_llm`, `deleted_at` |
| `idea_tags` | M:N идей и тегов | `idea_id`, `tag_id` (PK) |
| `finance_transactions` | доходы/расходы | `amount`, `currency`, `type`, `category`, `account`, `date`, `note`, `is_private_for_llm`, `deleted_at` |

Особенности:

- `schemaVersion = 2`; миграция `v1 → v2` создаёт таблицы в порядке
  родитель → связи и FTS5-индекс. Политика — ADR-012.
- Включён `PRAGMA foreign_keys = ON` в `beforeOpen`; удаление категории
  обнуляет ссылку, удаление сущности каскадно чистит связи тегов.
- Soft-delete (`deleted_at`) у заметок, задач, идей и финансов. Списки и
  экспорт по умолчанию исключают удалённые строки.
- Индексы: категория/soft-delete заметок, статус/срок задач, soft-delete идей,
  дата/тип и soft-delete финансов.
- Идеи: колонка БД называется `content` (геттер `text` конфликтует с
  Drift-билдером), доменное поле — `text`.

### Domain и репозитории

Доменные сущности и черновики (draft) находятся в
`lib/features/*/domain/`; интерфейсы и Drift-реализации — в
`lib/data/repositories/`:

- `notes_repository.dart` — CRUD, список с тегами/категориями, soft-delete;
- `categories_repository.dart` — CRUD, защита от циклов и удаления с дочерними
  категориями, `parent_id` → `NULL`;
- `tags_repository.dart` — resolve/create, переименование, удаление,
  регистронезависимое сравнение в Dart (SQLite `lower()` не работает с
  кириллицей);
- `tasks_repository.dart` — CRUD, смена статуса, теги, фильтры;
- `ideas_repository.dart` — CRUD, источник/настроение, теги;
- `finance_repository.dart` — CRUD, сводка доход/расход/баланс, CSV-сценарии;
- `search_repository.dart` — FTS5-поиск, `snippet`, `bm25`, privacy-фильтр;
- `repository_guard.dart` — единая обработка ошибок БД в `Result`;
- `tag_utils.dart` — нормализация и разрешение тегов.

Все операции возвращают `Result<T, AppException>`; ошибки БД логируются и
преобразуются в пользовательские сообщения.

### Полнотекстовый поиск

Реализован отдельной виртуальной таблицей FTS5 `search_index`
(`entity_type`, `entity_id`, `title`, `body`, `tags`, `is_private`) с
токенизатором `unicode61 remove_diacritics 2` (ADR-013).

- Индексация выполняется вручную из репозиториев при create/update/delete;
  операции с сущностью и индексом идут в одной транзакции.
- Поиск поддерживает несколько слов, кавычки/спецсимволы экранируются,
  результаты ранжируются `bm25`, сниппет выделяет совпадения `<<…>>`.
- `forLlm: false` (локальный поиск) видит приватные записи;
  `forLlm: true` исключает `is_private_for_llm = 1` из списков и FTS.
- После импорта JSON и CSV выполняется полная перестройка индекса.

### Приватность

Флаг `is_private_for_llm` есть у заметок, задач, идей и финансов. Локальный
поиск и UI показывают приватные записи (с бейджем `lock`), но слой будущей
LLM-интеграции обязан использовать репозитории с `forLlm: true`.

### Экспорт/импорт

`lib/data/backup/backup_service.dart`:

- JSON: экспорт всех сущностей (настройки, категории, заметки, теги, задачи,
  идеи, финансы), импорт **полностью заменяет** локальные данные.
- CSV: экспорт/импорт финансов по RFC 4180 (кавычки, запятые, переводы строк,
  BOM); импорт **добавляет** операции.
- После любого импорта FTS перестраивается.
- В настройках появилась секция «Данные»: экспорт/импорт по указанному пути;
  файлы экспорта по умолчанию пишутся в
  `<application support>/backups/`.

### UI

- Заметки: список, создание/редактирование, удаление, категория, теги,
  приватность, управление категориями.
- Задачи: список, CRUD, приоритет, статус, срок, теги, приватность,
  быстрое переключение «выполнено».
- Идеи: CRUD, источник, настроение, теги, приватность.
- Финансы: CRUD, доход/расход, дата, категория, счёт, сводка.
- Поиск: FTS-запрос, сниппеты, тип сущности, теги, приватность.
- Настройки: экспорт/импорт JSON/CSV.

Все строки добавлены в `app_en.arb` / `app_ru.arb`; `flutter gen-l10n`
выполнен.

## Проверки

Локально (Flutter 3.47.7, Dart 3.13.5):

```powershell
flutter gen-l10n
flutter analyze --fatal-infos   # 0 issues
flutter test                    # 45/45
flutter build windows --debug   # success
```

CI stage-01: [run 39763804171](https://github.com/HoudiwinG/second-brain/actions/runs/39763804171)
— **success**: `analyze-and-test` и `build-windows`.

Ключевые тесты:

- `test/db_migration_test.dart` — v1 → v2, сохранность `app_settings`,
  схема v2, `PRAGMA user_version`;
- `test/data_repositories_test.dart` — CRUD, теги, фильтры, soft-delete,
  приватность, ошибки;
- `test/search_repository_test.dart` — выдача, сниппеты, приватность,
  перестройка индекса, спецсимволы;
- `test/backup_service_test.dart` — JSON round-trip, CSV escaping/round-trip,
  замена/добавление данных, ошибки;
- `test/notes_screen_widget_test.dart` — создание заметки через диалог;
- `test/app_router_widget_test.dart` — навигация по экранам.

## Зависимости

- Runtime: `drift`, `drift_flutter`, `sqlite3` (ADR-011), `path_provider`.
- Dev: `drift_dev`, `build_runner`, `sqlite3: ^3.7.1` — для создания legacy
  v1-файла в тесте миграции.

## Принятые ограничения

- Финансовая сумма хранится как SQLite `REAL` (`double`) — возможны
  погрешности при суммировании; переход на целые минорные единицы — TD-21.
- Экспорт/импорт в UI работает по вводу пути, без file-picker — TD-23.
- Нет UI восстановления soft-deleted записей и окончательного удаления — TD-24.
- `User`, вложения заметок, learning-треки и чат не входят в stage-01 — TD-22.

## Ручная проверка GUI

Ручной прогон Windows-сборки выполнялся. Проверены основные экраны, трей и
глобальный хоткей `Ctrl+Alt+B`. Единственная найденная проблема — при высоте
окна меньше суммы 11 пунктов бокового rail появлялась жёлто-чёрная полоса
`RenderFlex overflowed by 72 pixels`. Исправлено включением прокрутки rail
(`NavigationRail.scrollable = true`); добавлен widget-тест на окно 1000×500.

## Связанные документы

- [ADR-013](../decisions.md)
- [ADR-014](../decisions.md)
- [Техдолг](../tech-debt.md)
- [Контекст](../context.md)
