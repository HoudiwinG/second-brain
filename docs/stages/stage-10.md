# Stage-10 — После MVP: sync core + web

- **Дата:** 2026-11-18
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **fixes ready**, ожидается повторное ревью. Первое ревью A/B —
  FAIL (деструктивный Pull без подтверждения/undo, UI не обновляется после
  restore); блокеры исправлены.
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
  push = export → backend; pull = backend → restore + rebuild FTS.
- Settings UI: «Синхронизация» — создать/активировать/удалить профиль,
  push/pull, статус последней синхронизации.
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
- CI `44317321230` (`cc9608e`) — success: analyze+test, build-web
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
- Предыдущий этап: [stage-09.md](stage-09.md).
