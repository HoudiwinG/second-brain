# Final review: Stage-07 (поиск идей)

- **Дата:** 2026-11-17
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `5ed3d99` (первое ревью — `a537265`)
- **Предыдущее ревью:** [stage-07-review.md](stage-07-review.md) — **FAIL**.
- **Исправления:** [stage-07-fix-results.md](stage-07-fix-results.md).

## Итог

- **Reviewer A: PASS WITH COMMENTS.** 0 critical, 0 major, 6 minor, 4 nit.
- **Reviewer B: PASS WITH COMMENTS.** 0 critical, 0 major, 2 minor, 1 nit.
- **Объединённый вердикт: PASS WITH COMMENTS (0 MAJOR).**
- **Гейты:** analyze 0; test **235/235**; CI `44020286840` (`5ed3d99`) —
  success, оба job'а.

## Статус блокера

- **S07-A-001 / S07-B-001 — fixed.** `ArticleSearchService` использует
  round-robin и дедупликацию по URL; при 10 Crossref + 1 HN в выдаче есть
  оба источника. Регрессионный тест «10+1» проходит.

## Остаточные комментарии (не блокеры)

- Нет per-tab loading/cancel; частичный отказ показывается общей ошибкой без
  указания источника.
- `Retry-After` не учитывается, Crossref `mailto`/версия UA не настроены.
- Изображения сохранены как ссылки/атрибуция; встроенного превью/скачивания
  нет (осознанно, чтобы не обходить `ApiClient`).
- Нет `license_url`/`license_version`, локального рендеринга изображения в
  заметке, защиты от повторного сохранения.
- Пагинация только первая страница; LLM-переранжирование не входит в этап.
- Live-smoke Crossref/HN/Openverse не выполнялся.

## Соответствие критериям

- [x] Научные статьи — Crossref.
- [x] Блогерские статьи — Hacker News, результаты доступны (round-robin).
- [x] Изображения — Openverse, `ImageSearchProvider`.
- [x] Сохранение в `IdeaEntry`/`Note`.
- [x] UI поиска: вкладки, loading/empty/error, сохранение.
- [x] Все сетевые вызовы через `ApiClient`.
- [x] ARB RU/EN.
- [x] Analyze 0, 235/235, Windows build (CI).
- [x] Схема v8 без миграций, новых зависимостей нет.

## Метод и ограничения

- Read-only; живые OAuth/API и GUI-smoke не выполнялись.
- A запускал analyze/test; B проверял CI/analyze.
