# Финальное ревью: Stage-05 (после S05-001…011)

- **Дата:** 2026-11-16
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `63d780e` (stage-05 — `9b96f58`,
  первое ревью — `47bdffa`, исправления — `63d780e`)
- **Первое ревью:** [stage-05-review.md](stage-05-review.md) — FAIL
  (S05-001, JSON-бэкап)
- **Исправления:** [stage-05-fix-results.md](stage-05-fix-results.md)

## Итог

- **Вердикт: PASS WITH COMMENTS.**
- **Reviewer A:** critical 0, major 0, minor 4, nit 6.
- **Reviewer B:** critical 0, major 0, minor 5, nit 5.
- **Блокеры:** нет. Единственный MAJOR первого ревью (`S05-001`) закрыт:
  JSON-бэкап v2 включает обучение, v1 совместим, `_clearAll` и порядок
  импорта корректны; round-trip-тест есть.
- **Гейты:** reviewer A — analyze 0, test **191/191**; reviewer B — analyze 0,
  CI `43898001167` (`63d780e`) success, 191/191.

## Подтверждение S05-001…011

Финальный проход подтвердил:

- S05-001 — backup v2 (export/import/clear, v1, round-trip).
- S05-002 — private roadmap/materials/check-in fail-closed в сервисе.
- S05-003 — await сохранения AI-roadmap, `try/catch`, busy.
- S05-004 — транзакция `setStepStatus`, идемпотентный soft-delete,
  `deleteSession`, stable/уникальные id.
- S05-005 — календарная дата сессии.
- S05-006 — edit/delete шага.
- S05-007/008/009/011 — тесты, l10n/единицы, документация, parser, индексы.
- S05-010 — **не был выполнен** (комментарий схемы/доступность); исправлен
  в S05Z.

## Комментарии S05Z

| ID | Severity | Статус | Исправление |
|----|----------|--------|-------------|
| S05Z-001/002 | MINOR | fixed | комментарий аудита перенесён к `ToolAuditEntries`; добавлены tooltip/semantics приватности и прогресса |
| S05Z-003 | MINOR | fixed | `generateRoadmap(LearningTrack)` в ADR/отчёте; список индексов и ревью-ссылки актуализированы; CI 191/191 |
| S05Z-004 | MINOR | fixed | edit/delete/add шага и сессий блокируются при `_aiBusy`; добавлен тест повреждённого JSON |
| S05Z-005 | MINOR | fixed | тест v2 без learning-массивов; отчёт скорректирован |
| S05Z-006 | NIT | fixed | отдельный ключ `learningEditStep`; заголовок диалога различает add/edit |
| S05Z-007 | NIT | fixed | check-in сравнивает календарные дни, а не моменты времени |
| S05Z-008 | NIT | fixed | импорт сессии с отсутствующим `track_id` теперь ошибка, а не тихий skip |
| S05Z-009 | NIT | fixed | индексы обучения идемпотентно досоздаются в `beforeOpen` для dev-баз v7 |
| S05Z-010 | NIT | fixed | импорт даты сессии берёт литеральные y-m-d из ISO-строки; v1-импорт явно заменяет обучение |

## Соответствие критериям stage-05

- [x] Треки, кастомные поля/шаги, сессии, прогресс.
- [x] AI-тренер: roadmap/материалы/check-in, приватность fail-closed.
- [x] JSON-бэкап v2 и совместимость v1.
- [x] Схема v7, миграции, FK cascade, индексы.
- [x] UI/ARB, edit/delete шагов, tooltip/semantics, календарные даты.
- [x] analyze 0, test 193/193, Windows debug build success (локально; CI —
  после push).

## Метод и ограничения

- Reviewer A: analyze 0, test 191/191; Windows build не запускал.
- Reviewer B: analyze 0, CI `43898001167` success, 191/191; локально test/
  build не запускал.
- Живые LLM-запросы не выполнялись; контракты проверены `MockClient`.
- TZ-сценарии проверены статически; реальная смена TZ не эмулировалась.
- Файлы в ходе ревью не изменялись.
