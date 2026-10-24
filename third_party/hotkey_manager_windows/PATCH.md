# Vendored patch: hotkey_manager_windows 0.2.0

Пакет скопирован из pub-кэша `hotkey_manager_windows-0.2.0` и пропатчен для
Second Brain (R02-009, ADR-017). Подключён через `dependency_overrides` в
корневом `pubspec.yaml`.

## Отличие от upstream

`windows/hotkey_manager_windows_plugin.cpp`, метод `Register`:

- проверяется `BOOL`, возвращённый `::RegisterHotKey(...)`;
- при `FALSE` вызывается `result->Error("hotkey_busy", ...)` с кодом
  `GetLastError()` и выполняется `return` до вставки в `hotkey_id_map_`;
- при успехе поведение не меняется.

Без патча upstream всегда отвечает `Success(true)`, даже если комбинация занята
другим приложением, поэтому `DesktopServices.setQuickCaptureHotkey` не мог
вернуть `false` и откат был недостижим.

## Обновление пакета

При обновлении `hotkey_manager` нужно заново сверить этот патч с новой версией
`hotkey_manager_windows` (см. ADR-017). Минимальный diff — только блок
`Register`; остальные файлы не изменялись.

Лицензия upstream сохранена в `LICENSE`.
