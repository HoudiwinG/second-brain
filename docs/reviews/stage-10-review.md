# Review: Stage-10 (sync core + web, первая итерация)

- **Дата:** 2026-11-18
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `cc9608e` (+ docs CI fix)
- **Отчёт:** [stages/stage-10.md](../stages/stage-10.md)
- **ADR:** ADR-027

## Итог

- **Reviewer A: PASS WITH COMMENTS.** 0 critical, 0 major, 11 minor, 9 nit.
- **Reviewer B: FAIL.** 0 critical, **2 major**, 10 minor, 3 nit.
- **Объединённый вердикт: FAIL.**
- **Гейты:** analyze 0, test 245/245; CI `44317321230` (`cc9608e`) success,
  artifacts Windows + web.

## Блокеры reviewer B

1. **S10-B-01 / S10-A-001 — Pull деструктивен без подтверждения и safety
   snapshot.** `pull` заменяет все локальные данные, UI не предупреждает,
   откат недоступен.
2. **S10-B-02 — После restore UI не обновляется.** Экраны держат кэши в
   `initState` и не получают сигнал об изменении данных.

## Ключевые неблокирующие

- Web DB silently falls back на in-memory без лога/баннера.
- Инвариант «один активный профиль» не enforced; `backendId` не
  маршрутизирует.
- `SyncStatus`/`syncError` не доходят до UI; `markSynced` игнорируется.
- Stub-снимки static, растут и общие между тестами.
- Нет тестов ошибок/rollback/undo/web.
- Privacy-scope для будущего облака не зафиксирован.
- Desktop-only UI не гейтится на web; web-метаданные placeholder.
- Провенанс `sqlite3.wasm`/`drift_worker.js` отсутствует.

## Метод

- A: analyze/test, CI/artifacts, code review.
- B: read-only code/CI, analyze; tests/build не запускались.
