# INDEX — карта документации

## Состояние
- Текущий этап: stage-01 (ядро данных) — **done**, CI зелёный (2026-10-22)
- Снимок состояния: [context.md](context.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md) — открытых позиций 0,
  принятых 14

## Процесс
- Исходные промпты (в корне репозитория): PROMPT.md (ТЗ), STAGE_ONE.md (этап 0),
  REVIEWER_PROMPT.md (агент-ревьюер)

## Старт для нового агента
1. Прочитай [INDEX.md](INDEX.md) (этот файл)
2. Прочитай [context.md](context.md) — текущее состояние
3. Прочитай [decisions.md](decisions.md) — все ADR
4. Прочитай [tech-debt.md](tech-debt.md) — открытый/принятый техдолг
5. Прочитай отчёт последнего этапа: [stages/stage-01.md](stages/stage-01.md)

## Отчёты по этапам
- [stage-00](stages/stage-00.md) — каркас (done, PASS WITH COMMENTS)
- [stage-01](stages/stage-01.md) — ядро данных (done, CI зелёный)
- stage-02 — UX-каркас (следующий)

## Шаблоны
- [decisions.template.md](decisions.template.md) — формат ADR
- [stages/stage-XX.template.md](stages/stage-XX.template.md) — формат отчёта этапа
- [reviews/stage-XX-review.template.md](reviews/stage-XX-review.template.md) — формат ревью

## Ревью
- [stage-00-review](reviews/stage-00-review.md) — **PASS WITH COMMENTS**
  (повторное ревью №2, 2026-10-22, agent-2); находки R00-001…R00-014 закрыты
  или осознанно приняты
  (см. [tech-debt.md](tech-debt.md#закрыто-по-ревью-stage-00-r00-2026-10-22)),
  R00-015/R00-016 (minor, документация) закрыты; CI зелёный.
- [stage-00-review-results](reviews/stage-00-review-results.md) — краткие
  результаты повторного ревью №2 и задачи для agent-1 (2026-10-22)
- Ревью stage-01 — не проводилось (следующий шаг после push).

## Решения
- [decisions.md](decisions.md) — все ADR
- Разделы:
  - architecture: ADR-001, ADR-002, ADR-004, ADR-005, ADR-008, ADR-012
  - security: ADR-003
  - dependency: ADR-006, ADR-007, ADR-011
  - integration: ADR-006, ADR-009, ADR-014
  - ux: ADR-005, ADR-008, ADR-010
  - data/search: ADR-013

## Дебаг
- [debug/log.md](debug/log.md) — хронология находок
- Паттерны ошибок: см. раздел «Паттерны ошибок» в log.md

## Архитектура
- Схема слоёв: см. ADR-001, ADR-008 (feature-first + core + data)
- Схема БД: см. ADR-002 (v1: app_settings), ADR-012 (политика миграций),
  [context.md](context.md) (v2: ядро данных)
- FTS5: ADR-013; экспорт/импорт: ADR-014
- Навигация: см. ADR-005 (11 веток FeatureBranch)
- Системная интеграция: ADR-006, ADR-010 (локализованный трей)
- LLM-слой и tools: этап 3 (не начат)
