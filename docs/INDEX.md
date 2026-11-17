# INDEX — карта документации

## Состояние
- Текущий этап: stage-08 (глобальный поиск + аналитика) — **PASS WITH
  COMMENTS (0 MAJOR)** после первого FAIL-ревью. FTS расширен
  обучением/чатом/почтой, SQL-фильтры типа/даты, backfill индекса, экран
  аналитики; схема **v8** без изменений. Analyze 0, test **241/241**, Windows
  debug build success; CI `44030371436` (`3743fc2`) — success.
- Предыдущий этап: stage-07 — **PASS WITH COMMENTS (0 MAJOR)** после первого
  FAIL-ревью; CI `44020286840` (`5ed3d99`) — success, 235/235.
- Предыдущий этап: stage-06 (почта) — **PASS WITH COMMENTS (0 MAJOR)** после
  двух FAIL-кругов; OAuth 2.0 + PKCE, Gmail API, Yandex 360 Mail API,
  Mail.ru отключён, локальный кэш/поиск, privacy; схема v8, backup v3.
  Analyze 0, test 228/228. Stage-05 — PASS WITH COMMENTS; stage-04 — PASS
  WITH COMMENTS; stage-03 — PASS; stage-02 — PASS WITH COMMENTS.
- Гейты stage-08 (2026-11-17): `flutter analyze --fatal-infos` — **No issues
  found**, `flutter test` — **241/241**, `flutter build windows --debug` —
  **success**; CI
  [44030371436](https://github.com/HoudiwinG/second-brain/actions/runs/44030371436)
  (`3743fc2`) — success, оба job'а.
- Гейты stage-07 (2026-11-17): analyze 0, test 235/235, Windows debug build
  success; CI
  [44020286840](https://github.com/HoudiwinG/second-brain/actions/runs/44020286840)
  (`5ed3d99`) — success, оба job'а.
- Гейты stage-06 (2026-11-16): analyze 0, test 228/228, Windows debug build
  success; CI
  [43929611715](https://github.com/HoudiwinG/second-brain/actions/runs/43929611715)
  (`952a1e9`) — success.
- Локальные гейты stage-03 (2026-10-28): analyze 0, test 132/132, Windows debug
  build; CI `40636764573` (`49bc00f`, включая `14e63a7`) — success.
- Снимок состояния: [context.md](context.md)
- Отчёт stage-08: [stages/stage-08.md](stages/stage-08.md).
- Отчёт stage-07: [stages/stage-07.md](stages/stage-07.md).
- Отчёт stage-06: [stages/stage-06.md](stages/stage-06.md).
- Отчёт stage-05: [stages/stage-05.md](stages/stage-05.md).
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
- Повторное независимое ревью stage-04 (2026-11-16, два прохода):
  [reviews/stage-04-repeat-review.md](reviews/stage-04-repeat-review.md) —
  **FAIL**, critical 0, major 3, minor 5, nit 3 после объединения дублей.
  Блокеры: `S04R-001`, `S04R-002`, `S04R-003`. Исходные S04-001…S04-009
  закрыты (S04-006 — код исправлен, не хватает regression-теста смены треда).
- [stage-04-repeat-fix-results](reviews/stage-04-repeat-fix-results.md) —
  self-check исправлений S04R-001…S04R-011 и комментариев S04F: fixed,
  тесты 172/172, analyze 0, Windows debug build success.
- [stage-04-final-review](reviews/stage-04-final-review.md) — финальное
  ревью (2026-11-16, два прохода): **PASS WITH COMMENTS**, 0 MAJOR; S04F
  verified, S04Z fixed; stage-05 разблокирован.
- [stage-05-review](reviews/stage-05-review.md) — первое ревью (2026-11-16,
  два прохода): reviewer A **FAIL** (1 MAJOR — JSON-бэкап), reviewer B
  **PASS WITH COMMENTS**; объединённый **FAIL**.
- [stage-05-fix-results](reviews/stage-05-fix-results.md) — self-check
  исправлений S05-001…S05-011 и S05Z: fixed, test 193/193, analyze 0,
  Windows debug build success.
- [stage-05-final-review](reviews/stage-05-final-review.md) — финальное ревью
  (2026-11-16, два прохода): **PASS WITH COMMENTS**, 0 MAJOR; S05Z fixed;
  stage-06 разблокирован.
- [stage-06-review](reviews/stage-06-review.md) — первое ревью A/B
  (2026-11-16, `2c377a6`): **FAIL**, A — 1 critical/8 major/8 minor/1 nit,
  B — 0 critical/3 major/12 minor/2 nit.
- [stage-06-re-review](reviews/stage-06-re-review.md) — повторное ревью A/B
  (2026-11-16, `f568f17`): **FAIL**, A — 3 major, B — 3 major.
- [stage-06-final-review](reviews/stage-06-final-review.md) — финальное
  ревью A/B (2026-11-16, `1ad2caa`; финал `952a1e9`):
  **PASS WITH COMMENTS (0 MAJOR)**.
- [stage-06-fix-results](reviews/stage-06-fix-results.md) — исправления
  первого/второго/финального круга; analyze 0, test 228/228.
- [stage-07-review](reviews/stage-07-review.md) — первое ревью A/B
  (2026-11-17, `a537265`): **FAIL**, блокер HN-выдачи.
- [stage-07-final-review](reviews/stage-07-final-review.md) — финальное
  ревью A/B (2026-11-17, `5ed3d99`): **PASS WITH COMMENTS (0 MAJOR)**.
- [stage-07-fix-results](reviews/stage-07-fix-results.md) — round-robin,
  UI/сеть/тесты; analyze 0, test 235/235.
- [stage-08-review](reviews/stage-08-review.md) — первое ревью A/B
  (2026-11-17, `d672da0`): **FAIL** (фильтры/backfill/валюты/лимит).
- [stage-08-final-review](reviews/stage-08-final-review.md) — финальное
  ревью A/B (2026-11-17, `3743fc2`): **PASS WITH COMMENTS (0 MAJOR)**.
- [stage-08-fix-results](reviews/stage-08-fix-results.md) — SQL-фильтры,
  backfill индекса, RUB-only аналитика, count; analyze 0, test 241/241.
- Исправления stage-04:
  [reviews/stage-04-fix-results.md](reviews/stage-04-fix-results.md) — все 9
  исходных находок закрыты коммитом `821b4f8` (+ docs-коммит).
- Исправления после повторного ревью stage-04:
  [reviews/stage-04-repeat-fix-results.md](reviews/stage-04-repeat-fix-results.md)
  — все 11 находок `S04R-001…S04R-011` и комментарии S04F fixed; analyze 0,
  test 172/172, Windows debug build success; финальная проверка — PASS WITH
  COMMENTS (0 MAJOR).

## Процесс
- Исходные промпты (в корне репозитория): PROMPT.md (ТЗ), STAGE_ONE.md (этап 0),
  REVIEWER_PROMPT.md (агент-ревьюер)

## Старт для нового агента
1. Прочитай [INDEX.md](INDEX.md) (этот файл)
2. Прочитай [context.md](context.md) — текущее состояние
3. Прочитай [decisions.md](decisions.md) — все ADR
4. Прочитай [tech-debt.md](tech-debt.md) — открытый/принятый техдолг
5. Прочитай отчёт последнего этапа: [stages/stage-08.md](stages/stage-08.md)

## Отчёты по этапам
- [stage-00](stages/stage-00.md) — каркас (done, PASS WITH COMMENTS)
- [stage-01](stages/stage-01.md) — ядро данных (done, CI зелёный)
- [stage-02](stages/stage-02.md) — UX-каркас (done; **PASS WITH COMMENTS**,
  ревью №3: 0 MAJOR, R02-014/R02-015 — не блокирующие комментарии; локальные
  проверки 77/77, Windows smoke и 6 CI-run подтверждены)
- [stage-03](stages/stage-03.md) — LLM-слой (done; исходное ревью **FAIL**
  сохранено, повторное — **PASS** 28/28; 132/132, analyze 0, Windows debug
  build, CI `40636764573` success; stage-04 разблокирован)
- [stage-04](stages/stage-04.md) — инструменты ассистента (исходное ревью
  **FAIL**, 9/9 fixed; повторное **FAIL** → **PASS WITH COMMENTS** после
  S04R, 11/11 fixed; S04F/S04Z fixed; analyze 0, test 172/172, Windows debug
  build success; ADR-021; схема v6; stage-05 разблокирован)
- [stage-05](stages/stage-05.md) — обучение (треки, roadmap, сессии,
  AI-тренер, backup v2; ADR-022; схема v7; первое ревью **FAIL** по
  S05-001 → **PASS WITH COMMENTS** после S05/S05Z; analyze 0, test 193/193,
  Windows debug build success)
- [stage-06](stages/stage-06.md) — почта (OAuth 2.0 + PKCE, secure tokens,
  Gmail API, Yandex 360 Mail API, Mail.ru disabled, кэш/поиск,
  per-message privacy, суммаризация, задача; ADR-023; схема v8, backup v3;
  analyze 0, test 228/228, Windows debug build success; два FAIL-круга →
  **PASS WITH COMMENTS (0 MAJOR)**)
- [stage-07](stages/stage-07.md) — поиск идей (Crossref + Hacker News,
  Openverse, сохранение в идеи/заметки; ADR-024; схема v8 без изменений;
  analyze 0, test 235/235, Windows debug build success; FAIL → **PASS WITH
  COMMENTS (0 MAJOR)**)
- [stage-08](stages/stage-08.md) — глобальный поиск + аналитика (FTS по
  обучению/чату/почте, SQL-фильтры, аналитика; ADR-025; схема v8; analyze 0,
  test 241/241, Windows build success; FAIL → **PASS WITH COMMENTS**)

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
    ADR-016, ADR-018, ADR-019, ADR-020, ADR-021, ADR-022, ADR-023, ADR-024,
    ADR-025
  - security: ADR-003, ADR-018, ADR-020, ADR-021, ADR-022, ADR-023
  - dependency: ADR-006, ADR-007, ADR-011, ADR-017
  - integration: ADR-006, ADR-009, ADR-014, ADR-017, ADR-019, ADR-023, ADR-024
  - ux: ADR-005, ADR-008, ADR-010, ADR-016
  - data/search: ADR-013, ADR-024, ADR-025
  - schema: ADR-002, ADR-012, ADR-015, ADR-018, ADR-021, ADR-022, ADR-023

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
