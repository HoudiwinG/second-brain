# Stage-10 — результаты исправлений после FAIL-ревью

- **Дата:** 2026-11-18
- **Исходное ревью:** [stage-10-review.md](stage-10-review.md)
- **Состояние до исправлений:** `cc9608e`
- **Статус:** исправления готовы, ожидается повторное ревью.

## Блокеры

### S10-B-01 / S10-A-001 — деструктивный Pull

- UI показывает подтверждение с предупреждением «все локальные данные будут
  заменены».
- `LocalSyncService.pull` перед restore строит локальный safety snapshot;
  `undoLastPull()` восстанавливает его.
- В настройках появляется «Отменить последний pull» после успешного pull.
- Тест: pull → восстановление снимка → undo возвращает локальное состояние.

### S10-B-02 — UI не обновляется после restore

- `syncDataVersionProvider` инкрементируется после pull/undo; `SecondBrainApp`
  пересоздаёт subtree через `KeyedSubtree`, экраны перечитывают кэши.
- Pull/undo больше не оставляют «фантомные» старые списки.

## Неблокирующие исправления

- `setActive` проверяет существование id (инвариант одного активного).
- `backendId` сверяется с активным backend перед push/pull.
- `markSynced` проверяется; ошибка возвращается наружу.
- Web-подключение логирует выбранную реализацию Drift и missing features.
- Ошибка чтения профилей показывается в UI, а не маскируется пустым списком.
- `_setActive`/`_delete` обрабатывают `Result`.
- Stub-снимки стали instance-level (не static).
- Добавлены тесты pull без снимка, undo и неизвестного профиля; 246/246.
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
flutter test                        246/246 passed
flutter build windows --debug       success
flutter build web --release         success
```
