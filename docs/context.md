# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-00 (каркас)
- **Статус:** done (с оговоркой по критерию сборки, см. ниже)
- **Последний закрытый этап:** stage-00 (PASS не подтверждён ревью — агент-2 ещё не проверял)
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0
- **Сборка:** `flutter analyze` OK (0 issues); `flutter build windows` — blocked (нет Visual Studio C++)
- **Тесты:** зелёные 15/15 (`flutter test`)
- **Flutter SDK:** 3.47.7 stable, установлен в C:\src\flutter (добавлен в PATH пользователя)

## Активные фича-флаги
- experimental.llmChat = true (заготовка, не используется)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Открытые вопросы / блокеры
- БЛОКЕР: Visual Studio Build Tools (workload «Desktop development with C++»)
  не установлены → `flutter build windows` невыполним. После установки VS —
  выполнить сборку и закрыть пункт критериев (ADR-007).
- Миграции на этапе 0 используются только для проверки механизма; на этапе 1 —
  реальные таблицы Note/Category/Task/IdeaEntry/FinanceTransaction + FTS5 (см. PROMPT.md).
- tray_manager зафиксирован на 0.5.0 (ADR-006); миграция на nativeapi после VS.

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
- ADR-007: build windows отложен до VS

## Активный агент
- agent-1: GLM-5.3-Flash-Free (OpenCode), ветка master
- agent-2: не активен (ревью stage-00 ожидается)

## Ссылки
- Последний отчёт: [stages/stage-00.md](stages/stage-00.md)
- Шаблон ревью: [reviews/stage-XX-review.template.md](reviews/stage-XX-review.template.md)
