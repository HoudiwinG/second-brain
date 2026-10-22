# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-00 (каркас)
- **Статус:** done; техдолг закрыт (см. [tech-debt.md](tech-debt.md), открытых позиций 0)
- **Последний закрытый этап:** stage-00 (ревью FAIL; исправления R00 подтверждены зелёным CI, ожидается повторное ревью)
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0
- **Сборка:** `flutter analyze` OK (0 issues); `flutter test` — 21/21;
  CI [run 39746024266](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266)
  — **success**: `analyze-and-test` и `build-windows` (включая Windows-тесты)
- **Тесты:** зелёные 21/21 (`flutter test`)
- **Flutter SDK:** 3.47.7 stable, установлен в C:\src\flutter (добавлен в PATH пользователя)

## Активные фича-флаги
- experimental.llmChat = true (заготовка, не используется)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Открытые вопросы / блокеры
- Техдолг закрыт (TD-01…TD-13), принятые позиции TD-14…TD-20 — в
  [tech-debt.md](tech-debt.md). Находки ревью R00-001…R00-012 закрыты или
  осознанно приняты (см. раздел «Закрыто по ревью stage-00»).
- R00-001 **закрыт**: коммит `64ab3a6` запушен, оба CI-job'а зелёные
  (`analyze-and-test`, `build-windows`). Локально: analyze 0 issues, test 21/21.
- Локальная сборка `flutter build windows` требует Visual Studio
  Build Tools (workload «Desktop development with C++»); на машине идёт
  установка, для критерия этапа 0 достаточно CI-job'а `build-windows` (ADR-009).
- Миграции на этапе 0 используются только для проверки механизма; на этапе 1 —
  реальные таблицы Note/Category/Task/IdeaEntry/FinanceTransaction + FTS5
  (см. PROMPT.md). `onUpgrade` намеренно падает при неизвестном переходе —
  миграция v1→v2 добавляется явно (ADR-012).
- tray_manager зафиксирован на 0.5.0 (ADR-006); миграция на nativeapi после
  установки VS / на stage-02.
- Ревью stage-00 проведено агентом-2 (2026-10-22): **FAIL**, 5 major / 4 minor /
  3 nit; все находки закрыты, CI зелёный — ожидается повторное ревью.

## Ближайшие задачи (следующий этап — stage-01 «Ядро данных»)
- Drift: таблицы Note, Category, Task, IdeaEntry, FinanceTransaction (+user)
- CRUD-репозитории + FTS5-поиск
- флаг is_private_for_llm на сущностях
- экспорт/импорт JSON/CSV
- миграция schemaVersion 1 → 2 (+ тесты миграции)

## Последние ключевые ADR
- ADR-001: Riverpod как DI/стейт
- ADR-002: Drift, схема v1 (app_settings)
- ADR-003: SecretStore через flutter_secure_storage
- ADR-006: tray_manager пин 0.5.0
- ADR-009: сборка Windows проверяется в CI (закрывает оговорку ADR-007)
- ADR-010: локализация трея/заголовка окна через ARB
- ADR-011: отказ от sqlite3_flutter_libs (sqlite3 3.x + hooks)
- ADR-012: политика миграций — без createAll в onUpgrade

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 проведено 2026-10-22 (FAIL); CI зелёный, ожидает
  повторного ревью

## Ссылки
- Последний отчёт: [stages/stage-00.md](stages/stage-00.md)
- Ревью: [reviews/stage-00-review.md](reviews/stage-00-review.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md)
- Шаблон ревью: [reviews/stage-XX-review.template.md](reviews/stage-XX-review.template.md)

## Репозиторий
- Удалённый: **https://github.com/HoudiwinG/second-brain** (приватный), ветка master
- Выгрузка: 2026-10-22, коммиты 50afd6b / 58cb23b / 1265a37 / **64ab3a6**
  (`chore(stage-00): закрыть техдолг и находки ревью`)
- CI-прогон для 64ab3a6:
  https://github.com/HoudiwinG/second-brain/actions/runs/39746024266
  — **success**; jobs:
  [analyze-and-test](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266/job/119714562468) /
  [build-windows](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266/job/119714562295)
- CI: GitHub Actions (.github/workflows/ci.yml) — pub get --enforce-lockfile +
  analyze + test (ubuntu) + test + build windows --debug (windows-latest)
- Секреты: `.env` исключён в .gitignore (после выгрузки добавлена гарантия
  `.env` / `.env.*` / `!.env.example` — проверено `git ls-files`); в репозитории
  только `.env.example`. Локальные дампы сессий агента тоже в .gitignore.
