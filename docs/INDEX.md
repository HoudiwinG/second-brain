# INDEX — карта документации

## Состояние
- Текущий этап: stage-00 (каркас) — **done**; техдолг закрыт (2026-10-22)
- Снимок состояния: [context.md](context.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md) — открытых позиций 0

## Процесс
- Исходные промпты (в корне репозитория): PROMPT.md (ТЗ), STAGE_ONE.md (этап 0),
  REVIEWER_PROMPT.md (агент-ревьюер)

## Старт для нового агента
1. Прочитай [INDEX.md](INDEX.md) (этот файл)
2. Прочитай [context.md](context.md) — текущее состояние
3. Прочитай [decisions.md](decisions.md) — все ADR
4. Прочитай [tech-debt.md](tech-debt.md) — открытый/принятый техдолг
5. Прочитай отчёт последнего этапа: [stages/stage-00.md](stages/stage-00.md)

## Отчёты по этапам
- [stage-00](stages/stage-00.md) — каркас (done)
- stage-01 — ядро данных (не начат)

## Шаблоны
- [decisions.template.md](decisions.template.md) — формат ADR
- [stages/stage-XX.template.md](stages/stage-XX.template.md) — формат отчёта этапа
- [reviews/stage-XX-review.template.md](reviews/stage-XX-review.template.md) — формат ревью

## Ревью
- [stage-00-review](reviews/stage-00-review.md) — **FAIL** (2026-10-22, agent-2);
  находки R00-001…R00-012 закрыты разработчиком (см.
  [tech-debt.md](tech-debt.md#закрыто-по-ревью-stage-00-r00-2026-10-22)),
  повторное ревью — после push/CI

## Решения
- [decisions.md](decisions.md) — все ADR
- Разделы:
  - architecture: ADR-001, ADR-002, ADR-004, ADR-005, ADR-008, ADR-012
  - security: ADR-003
  - dependency: ADR-006, ADR-007, ADR-011
  - integration: ADR-006, ADR-009
  - ux: ADR-005, ADR-008, ADR-010

## Дебаг
- [debug/log.md](debug/log.md) — хронология находок
- Паттерны ошибок: см. раздел «Паттерны ошибок» в log.md

## Архитектура
- Схема слоёв: см. ADR-001, ADR-008 (feature-first + core + data)
- Схема БД: см. ADR-002 (v1: app_settings), ADR-012 (политика миграций)
- Навигация: см. ADR-005 (11 веток FeatureBranch)
- Системная интеграция: ADR-006, ADR-010 (локализованный трей)
- LLM-слой и tools: этап 3 (не начат)
