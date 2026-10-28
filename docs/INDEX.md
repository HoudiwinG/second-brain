# INDEX — карта документации

## Состояние
- Текущий этап: stage-03 (LLM-слой). Исходное независимое ревью —
  **FAIL** (2026-10-25, два агента), вердикт сохранён. Все 28 находок
  S03-001…S03-028 исправлены коммитом `14e63a7`; **повторное независимое
  ревью ещё не проводилось**, поэтому stage-04 **заблокирован**.
  Stage-02 закрыт с вердиктом **PASS WITH COMMENTS** (ревью №3);
  R02-001…R02-013 закрыты, R02-014/R02-015 остаются не блокирующими
  комментариями.
- Локальные гейты после исправлений (2026-10-28): `flutter analyze
  --fatal-infos` — **No issues found**, `flutter test` — **132/132**,
  `flutter build windows --debug` — **success**. CI-run
  [40636764573](https://github.com/HoudiwinG/second-brain/actions/runs/40636764573)
  (`49bc00f`, включающий `14e63a7`) — **success** (оба job'а).
- Снимок состояния: [context.md](context.md)
- Отчёт stage-03: [stages/stage-03.md](stages/stage-03.md).
- Ревью stage-03: [reviews/stage-03-review.md](reviews/stage-03-review.md) —
  **FAIL**, critical 0, major 3, minor 17, nit 8; полный список
  S03-001…S03-028.
- Исправления stage-03:
  [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md) —
  все 28 закрыты в коде и тестах, новых TD нет; ожидается независимое
  подтверждение.
- Ревью stage-02: актуальный вердикт **PASS WITH COMMENTS** (ревью №3,
  critical 0, major 0, minor 1, nit 1); исторические **FAIL** — ревью и
  повторное №2; см. [reviews/stage-02-review.md](reviews/stage-02-review.md).
  Исправления R02-001…R02-008 —
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md),
  R02-009…R02-013 —
  [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md) — открытых TD 0,
  принятых 15, исправлено 37 (включая R02-001…R02-013, TD-27, TD-16);
  R02-014 (MINOR) и R02-015 (NIT) остаются комментариями ревью №3.
  S03-находки — не TD: 28 fixed, ожидают повторного ревью. TD-28
  (UI выбора контекста) остаётся accepted.

## Процесс
- Исходные промпты (в корне репозитория): PROMPT.md (ТЗ), STAGE_ONE.md (этап 0),
  REVIEWER_PROMPT.md (агент-ревьюер)

## Старт для нового агента
1. Прочитай [INDEX.md](INDEX.md) (этот файл)
2. Прочитай [context.md](context.md) — текущее состояние
3. Прочитай [decisions.md](decisions.md) — все ADR
4. Прочитай [tech-debt.md](tech-debt.md) — открытый/принятый техдолг
5. Прочитай отчёт последнего этапа: [stages/stage-03.md](stages/stage-03.md)

## Отчёты по этапам
- [stage-00](stages/stage-00.md) — каркас (done, PASS WITH COMMENTS)
- [stage-01](stages/stage-01.md) — ядро данных (done, CI зелёный)
- [stage-02](stages/stage-02.md) — UX-каркас (done; **PASS WITH COMMENTS**,
  ревью №3: 0 MAJOR, R02-014/R02-015 — не блокирующие комментарии; локальные
  проверки 77/77, Windows smoke и 6 CI-run подтверждены)
- [stage-03](stages/stage-03.md) — LLM-слой (self-check исправлений done;
  исходное ревью **FAIL**, 28 находок fixed в `14e63a7`, 132/132, analyze 0,
  Windows debug build, CI `40636764573` success; повторное ревью ожидается;
  stage-04 заблокирован)
- stage-04 — инструменты ассистента (только после успешного повторного ревью
  stage-03)

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
- Ревью stage-01 — не проводилось.
- [stage-03-review](reviews/stage-03-review.md) — **FAIL** (2026-10-25, два
  независимых прохода): critical 0, major 3, minor 17, nit 8 после
  объединения дублей. Блокеры: S03-001, S03-002, S03-003. Вердикт сохранён.
- [stage-03-fix-results](reviews/stage-03-fix-results.md) — self-check
  исправлений S03-001…S03-028 (2026-10-28): все fixed, 132/132, analyze 0,
  build success; исходный FAIL не переписан, повторное ревью ожидается.
- [stage-02-review](reviews/stage-02-review.md) — **PASS WITH COMMENTS**
  (повторное ревью №3, 2026-10-24, agent-2): critical 0, major 0, minor 1
  (R02-014), nit 1 (R02-015); R02-009…R02-013 закрыты. Исторические ревью:
  **FAIL** (2026-10-23; 2 MAJOR), повторное №2 (2026-10-24; 1 MAJOR R02-009,
  2 MINOR, 2 NIT).
- [stage-02-review-results](reviews/stage-02-review-results.md) — self-check
  agent-1: все R02-001…R02-008 исправлены, тесты 69/69, smoke из каталога
  `.exe`; фактические результаты проверены в повторном ревью №2.
- [stage-02-fix-tasks](reviews/stage-02-fix-tasks.md) — задачи для agent-1 по
  R02-009…R02-013 и патч-предложения (2026-10-24, agent-2); R02-009 —
  блокер stage-03.
- [stage-02-fix-results](reviews/stage-02-fix-results.md) — self-check agent-1
  по R02-009…R02-013 (2026-10-24): вариант A, backoff, валюты, refresh, лог;
  analyze 0, test 77/77, build success, ручной сценарий занятой комбинации;
  ревью №3 подтвердило исправления и дало **PASS WITH COMMENTS**.

## Решения
- [decisions.md](decisions.md) — все ADR
- Разделы:
  - architecture: ADR-001, ADR-002, ADR-004, ADR-005, ADR-008, ADR-012,
    ADR-016, ADR-018, ADR-019, ADR-020
  - security: ADR-003, ADR-018, ADR-020
  - dependency: ADR-006, ADR-007, ADR-011, ADR-017
  - integration: ADR-006, ADR-009, ADR-014, ADR-017, ADR-019
  - ux: ADR-005, ADR-008, ADR-010, ADR-016
  - data/search: ADR-013
  - schema: ADR-002, ADR-012, ADR-015, ADR-018

## Дебаг
- [debug/log.md](debug/log.md) — хронология находок
- Паттерны ошибок: см. раздел «Паттерны ошибок» в log.md

## Архитектура
- Схема слоёв: см. ADR-001, ADR-008 (feature-first + core + data)
- Схема БД: см. ADR-002 (v1: app_settings), ADR-012 (политика миграций),
  ADR-015 (v3: напоминания), ADR-018 (v5: LLM-конфигурации и чат),
  [context.md](context.md)
- FTS5: ADR-013; экспорт/импорт: ADR-014
- Навигация: см. ADR-005 (11 веток FeatureBranch)
- Системная интеграция: ADR-006, ADR-010 (трей), ADR-016 (быстрый ввод,
  хоткей, toast)
- LLM-слой: ADR-018 (схема/секреты), ADR-019 (HTTP/SSE), ADR-020 (контракт
  провайдеров, privacy guard, tools/RAG). Реальное выполнение tools —
  stage-04.
