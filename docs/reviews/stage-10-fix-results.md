# Stage-10 — результаты исправлений после FAIL-ревью

- **Дата:** 2026-11-18
- **Исходное ревью:** [stage-10-review.md](stage-10-review.md)
- **Состояние до исправлений:** `cc9608e`
- **Статус:** исправления подтверждены финальным ревью A3/B3 —
  **PASS WITH COMMENTS (0 MAJOR)**; см.
  [stage-10-final-review.md](stage-10-final-review.md).

## Блокеры

### S10-B-01 / S10-A-001 — деструктивный Pull

- UI показывает подтверждение с предупреждением «все локальные данные будут
  заменены» (и отдельное подтверждение для undo).
- `LocalSyncService.pull` перед restore строит safety snapshot с
  `includeDeleted: true`; `undoLastPull()` восстанавливает его.
- Доступность undo хранится в `syncUndoAvailableProvider`, а не в state
  виджета, поэтому кнопка не теряется при refresh.
- Тест: pull → восстановление снимка → undo возвращает локальное состояние.

### S10-B-02 — UI не обновляется после restore

- `syncDataVersionProvider` инкрементируется после pull/undo; `SyncRefreshHost`
  оборачивает экраны веток (и analytics) и пересоздаёт только экран, не
  Router/Navigator, поэтому `initState`-кэши перечитываются.
- Pull/undo больше не оставляют «фантомные» старые списки; undo-кнопка
  управляется провайдером.

## Неблокирующие исправления

- `setActive` проверяет существование id (инвариант одного активного).
- `backendId` сверяется с активным backend перед push/pull.
- `markSynced` проверяется; ошибка возвращается наружу.
- Web-подключение логирует выбранную реализацию Drift и missing features.
- Ошибка чтения профилей показывается в UI, а не маскируется пустым списком.
- `_setActive`/`_delete` обрабатывают `Result`.
- Stub-снимки стали instance-level (не static).
- Добавлены unit-тесты pull/undo/ошибок и widget-тесты доступности
  Push/Pull, busy-блокировки и появления undo; 248/248.
- ADR-027 уточняет privacy-scope snapshot для будущего облака.

## Остаточные ограничения

- Backend stub: снимок не переживает restart, OAuth/облако/RLS нет.
- Snapshot-sync перезаписывает данные; entity-level merge — позже.
- Web runtime smoke (secure storage, file UI, WASM DB) не выполнялся;
  desktop-only фичи пока не скрыты на web.
- Провенанс `sqlite3.wasm`/`drift_worker.js` и browser-smoke — техдолг.
- Профили не входят в JSON backup; подписка/биллинг/мобильные порты — после.

## Гейты

```text
flutter analyze --fatal-infos       0 issues
flutter test                        248/248 passed
flutter build windows --debug       success
flutter build web --release         success
```
