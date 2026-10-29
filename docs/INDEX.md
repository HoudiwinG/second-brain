# INDEX — карта документации

## Состояние
- Текущий этап: stage-04 (инструменты ассистента) — реализация `f2d9f08`,
  исправления по ревью `821b4f8`; все 9 находок `S04-001`…`S04-009` закрыты.
  Независимое ревью — **FAIL**, повторное ревью ещё не проводилось.
- Предыдущий этап: stage-03 (LLM-слой) **закрыт повторным независимым ревью:
  PASS** (2026-10-28). Исходное ревью остаётся **FAIL** (2026-10-25), вердикт
  сохранён. Все 28 находок S03-001…S03-028 исправлены коммитом `14e63a7` и
  подтверждены (28/28 verified). Stage-02 закрыт с вердиктом **PASS WITH
  COMMENTS** (ревью №3); R02-001…R02-013 закрыты, R02-014/R02-015 остаются
  не блокирующими комментариями.
- Локальные гейты stage-04 после исправлений (2026-10-29): `flutter analyze
  --fatal-infos` — **No issues found**, `flutter test` — **160/160**,
  `flutter build windows --debug` — **success**. CI на `f2d9f08` —
  [40830490442](https://github.com/HoudiwinG/second-brain/actions/runs/40830490442)
  success; run на `821b4f8` — после push.
- Локальные гейты stage-03 (2026-10-28): analyze 0, test 132/132, Windows debug
  build; CI `40636764573` (`49bc00f`, включая `14e63a7`) — success.
- Снимок состояния: [context.md](context.md)
- Отчёт stage-03: [stages/stage-03.md](stages/stage-03.md).
- Ревью stage-03: [reviews/stage-03-review.md](reviews/stage-03-review.md) —
  **FAIL**, critical 0, major 3, minor 17, nit 8; полный список
  S03-001…S03-028.
- Повторное ревью stage-03:
  [reviews/stage-03-repeat-review.md](reviews/stage-03-repeat-review.md) —
  **PASS**, 28/28 verified, 0 critical/0 major; S03R-001…S03R-004 —
  неблокирующие комментарии.
- Исправления stage-03:
  [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md) —
  все 28 закрыты в коде и тестах, новых TD нет; подтверждены повторным ревью.
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
  S03-находки — не TD: 28 fixed и подтверждены повторным ревью; S03R-001…
  S03R-004 — неблокирующие комментарии. TD-28 (UI выбора контекста) остаётся
  accepted.
- Независимое ревью stage-04 (2026-10-29):
  [reviews/stage-04-review.md](reviews/stage-04-review.md) — **FAIL**, critical 0,
  major 1 (`S04-001`), minor 7, nit 1. Блокер: Google-провайдер при нескольких
  tool calls в одном ответе формирует невалидную историю (N подряд идущих
  `user`-contents). Остальные находки — аудит, приватность `update_task_status`,
  тесты и документация.
- Исправления stage-04:
  [reviews/stage-04-fix-results.md](reviews/stage-04-fix-results.md) — все 9
  находок закрыты коммитом `821b4f8` (+ docs-коммит); analyze 0, test 160/160,
  Windows debug build success. Ожидается повторное независимое ревью.

## Процесс
- Исходные промпты (в корне репозитория): PROMPT.md (ТЗ), STAGE_ONE.md (этап 0),
  REVIEWER_PROMPT.md (агент-ревьюер)

## Старт для нового агента
1. Прочитай [INDEX.md](INDEX.md) (этот файл)
2. Прочитай [context.md](context.md) — текущее состояние
3. Прочитай [decisions.md](decisions.md) — все ADR
4. Прочитай [tech-debt.md](tech-debt.md) — открытый/принятый техдолг
5. Прочитай отчёт последнего этапа: [stages/stage-04.md](stages/stage-04.md)

## Отчёты по этапам
- [stage-00](stages/stage-00.md) — каркас (done, PASS WITH COMMENTS)
- [stage-01](stages/stage-01.md) — ядро данных (done, CI зелёный)
- [stage-02](stages/stage-02.md) — UX-каркас (done; **PASS WITH COMMENTS**,
  ревью №3: 0 MAJOR, R02-014/R02-015 — не блокирующие комментарии; локальные
  проверки 77/77, Windows smoke и 6 CI-run подтверждены)
- [stage-03](stages/stage-03.md) — LLM-слой (done; исходное ревью **FAIL**
  сохранено, повторное — **PASS** 28/28; 132/132, analyze 0, Windows debug
  build, CI `40636764573` success; stage-04 разблокирован)
- [stage-04](stages/stage-04.md) — инструменты ассистента (реализация `f2d9f08`,
  исправления по ревью `821b4f8`; исходное ревью **FAIL**, 9/9 fixed;
  analyze 0, 160/160, Windows debug build success, CI `40830490442`; ADR-021;
  схема v6; ожидается повторное ревью)

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
  build success; исходный FAIL не переписан.
- [stage-03-repeat-review](reviews/stage-03-repeat-review.md) — независимое
  повторное ревью (2026-10-28): **PASS**, 28/28 verified, 0 critical/0 major,
  2 minor (S03R-001/S03R-002) и 2 nit (S03R-003/S03R-004); stage-04
  разблокирован.
- [stage-04-review](reviews/stage-04-review.md) — независимое ревью (2026-10-29,
  agent-2): **FAIL**, critical 0, major 1 (S04-001: Google ломается на нескольких
  tool calls), minor 7, nit 1; гейты и CI подтверждены.
- [stage-04-fix-results](reviews/stage-04-fix-results.md) — self-check
  разработчика: 9/9 fixed (`821b4f8`), новые тесты и гейты; не вердикт ревью.
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
    ADR-016, ADR-018, ADR-019, ADR-020, ADR-021
  - security: ADR-003, ADR-018, ADR-020, ADR-021
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
