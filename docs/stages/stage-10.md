# Stage-10 — После MVP: sync core + web

- **Дата:** 2026-11-18
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **PASS WITH COMMENTS (0 MAJOR)** после трёх кругов A/B-ревью.
  Первое ревью — FAIL (деструктивный Pull, UI не обновляется), второе — FAIL
  (инвертированная busy-логика), финальное — PASS WITH COMMENTS.
- **Предыдущий этап:** stage-09 — **PASS WITH COMMENTS (0 MAJOR)**.
- **Схема БД:** **v8** без изменений.
- **ADR:** ADR-027.

## Выбранный объём
По согласованию: sync core + backend interface + stubs, локальные профили с
будущим OAuth, без реальных credentials, Windows + web.

## Что реализовано
- `SyncProfile` + `SyncProfileRepository` — локальные профили в
  `app_settings` (`sync.profiles`), один активный.
- `SyncBackend` / `StubSyncBackend` — push/pull снимка в памяти процесса.
- `LocalSyncService` — snapshot через `BackupService`:
  push = export → backend; pull = подтверждение → safety snapshot → restore →
  rebuild FTS; undo возвращает снимок до pull.
- Settings UI: «Синхронизация» — создать/активировать/удалить профиль,
  push/pull, undo, статус последней синхронизации.
- После restore `SyncRefreshHost` пересоздаёт экраны веток/analytics по
  `syncDataVersion`, не трогая Router/Navigator.
- Web:
  - `web/` (`index.html`, manifest, `sqlite3.wasm`, `drift_worker.js`);
  - условное подключение Drift: NativeDatabase (IO) / `drift/wasm` (web);
  - `DesktopServices` web-stub (трей/хоткей/window — no-op);
  - `universal_io` для компиляции файловых операций на web.
- CI: job `build-web` + artifact `second-brain-web`; Windows build/installer
  сохранены.

## Тесты
- `test/sync_service_test.dart` — push/pull snapshot, undo, ошибки, профили.
- `test/sync_settings_section_test.dart` — idle Push/Pull доступны, busy
  блокирует кнопки, undo появляется после pull.
- 3 unit-теста sync + 2 widget-теста настроек; всего **248/248**.
- `flutter analyze --fatal-infos` — 0 issues.
- `flutter build windows --debug` — success.
- `flutter build web --release` — success.
- CI `44329072922` (`3981839`) — success: analyze+test, build-web
  (`second-brain-web`), build-windows installer.

## Ограничения
- Backend — stub: снимок не переживает перезапуск, облака/OAuth/RLS нет.
- Snapshot-sync перезаписывает данные целиком; entity-level merge/CRDT —
  после MVP.
- Профили хранятся в `app_settings`, не в JSON backup.
- Подписка/мультиаккаунт UI — заготовка профилей, без биллинга.
- Web runtime (secure storage, file backup UI, WASM DB в браузере) не
  проверялся; сборка проверена.
- Мобильные порты не входят в первую итерацию.

## Дальше
- Выбрать реальный backend (Supabase/REST) + OAuth/RLS.
- Entity-level sync, conflict resolution, web-адаптация файловых операций.
- Подписка/биллинг и мобильные порты.

## Ссылки
- ADR-027.
- Первое ревью: [../reviews/stage-10-review.md](../reviews/stage-10-review.md)
  (**FAIL**).
- Исправления: [../reviews/stage-10-fix-results.md](../reviews/stage-10-fix-results.md).
- Финальное ревью:
  [../reviews/stage-10-final-review.md](../reviews/stage-10-final-review.md)
  (**PASS WITH COMMENTS, 0 MAJOR**).
- Предыдущий этап: [stage-09.md](stage-09.md).
