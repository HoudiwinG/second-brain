# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-01 (ядро данных)
- **Статус:** done локально; изменения подготовлены к коммиту/push. Техдолг:
  открытых позиций 0, принятых — 14 (см. [tech-debt.md](tech-debt.md)).
- **Последний закрытый этап:** stage-00 (ревью: FAIL → **PASS WITH COMMENTS**;
  R00-015/R00-016 закрыты, CI зелёный)
- **Текущий отчёт:** [stages/stage-01.md](stages/stage-01.md)
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0 (TD-21 — принятое ограничение `REAL` для финансов)
- **Сборка:** `flutter analyze --fatal-infos` — 0 issues;
  `flutter test` — **44/44**; `flutter build windows --debug` — **success**
- **Flutter SDK:** 3.47.7 stable, `C:\src\flutter` (Dart 3.13.5)
- **Ветка:** `master`; CI stage-01 — после push (workflow `.github/workflows/ci.yml`)

## Активные фича-флаги
- experimental.llmChat = true (заготовка, не используется)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Что сделано на stage-01

### Схема и данные
- Drift schema v2: `app_settings`, `categories`, `notes`, `tags`,
  `note_tags`, `tasks`, `task_tags`, `idea_entries`, `idea_tags`,
  `finance_transactions`.
- Явная миграция v1 → v2, FTS5-таблица `search_index`, индексы, soft-delete,
  `PRAGMA foreign_keys = ON`.
- FTS5: `unicode61 remove_diacritics 2`, `bm25`, `snippet`, ручная индексация
  из репозиториев (ADR-013).
- Приватность `is_private_for_llm`: локальный поиск видит приватные записи,
  `forLlm: true` исключает их из списков и FTS.

### Репозитории и сервисы
- CRUD-репозитории: notes, categories, tags, tasks, ideas, finance, search.
- `RepositoryGuard` + `Result<T, AppException>`; ошибки логируются.
- `BackupService`: JSON-экспорт/импорт всех сущностей, CSV-экспорт/импорт
  финансов (RFC 4180); JSON-импорт заменяет данные, CSV — добавляет;
  после импорта FTS перестраивается (ADR-014).

### UI
- Заметки: CRUD, категории (иерархия), теги, приватность.
- Задачи: CRUD, приоритет/статус/срок, теги, приватность.
- Идеи: CRUD, источник, настроение, теги, приватность.
- Финансы: CRUD, сводка доход/расход/баланс.
- Поиск: FTS-запрос, сниппеты, типы, теги, приватность.
- Настройки: секция «Данные» — экспорт/импорт JSON/CSV по пути.
- EN/RU ARB обновлены, `flutter gen-l10n` выполнен.

## Известные ограничения / принятый техдолг
- TD-21 (MAJOR, accepted): сумма финансов — `REAL`/`double`, возможны
  погрешности; триггер — бюджеты/аналитика на stage-02.
- TD-22 (MINOR, accepted): нет `User`, вложений, learning/chat-таблиц.
- TD-23 (MINOR, accepted): экспорт/импорт через ввод пути, без file-picker.
- TD-24 (MINOR, accepted): нет UI корзины/restore/purge для soft-delete.
- TD-14…TD-20 — ограничения stage-00 (трей 0.5.0, хоткей, golden-тесты и др.).
- Ручной прогон GUI (трей, `Ctrl+Alt+B`) не выполнялся; сборка Windows
  подтверждена локально.

## Ближайшие задачи (stage-02 «UX-каркас»)
- Довести UX экранов ядра данных, file-picker, корзину/restore.
- Настроить трей/хоткей по ТЗ stage-02; golden/визуальные тесты.
- Решить TD-21 перед финансовой аналитикой.
- Проверить CI после push stage-01 и зафиксировать run.

## Последние ключевые ADR
- ADR-001: Riverpod как DI/стейт
- ADR-002: Drift, схема v1 (app_settings)
- ADR-003: SecretStore через flutter_secure_storage
- ADR-006: tray_manager пин 0.5.0
- ADR-009: сборка Windows проверяется в CI
- ADR-010: локализация трея/заголовка окна через ARB
- ADR-011: отказ от sqlite3_flutter_libs (sqlite3 3.x + hooks)
- ADR-012: политика миграций — без createAll в onUpgrade
- ADR-013: FTS5 отдельной таблицей + ручная индексация
- ADR-014: JSON-импорт заменяет, CSV финансов добавляет

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; блокеров для stage-01 нет

## Ссылки
- Отчёт stage-01: [stages/stage-01.md](stages/stage-01.md)
- Отчёт stage-00: [stages/stage-00.md](stages/stage-00.md)
- Ревью stage-00: [reviews/stage-00-review.md](reviews/stage-00-review.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md)
- ADR: [decisions.md](decisions.md)
- Журнал дебага: [debug/log.md](debug/log.md)

## Репозиторий
- Удалённый: **https://github.com/HoudiwinG/second-brain** (приватный), ветка master
- HEAD до stage-01: `81779a6` (`docs: закрыть техдолг stage-00`), синхронизирован
  с `origin/master`.
- Изменения stage-01: схема/репозитории/UI/тесты/документация — в рабочем
  дереве (коммит и CI-run фиксируются после push).
- CI: GitHub Actions (`.github/workflows/ci.yml`) — pub get
  `--enforce-lockfile` + analyze + test (ubuntu) + test + build windows
  --debug (windows-latest).
- Секреты: `.env` исключён; в репозитории только `.env.example`.
