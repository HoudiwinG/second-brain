# Stage-09 — Полировка MVP

- **Дата:** 2026-11-17
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **fixes ready / self-check**, независимое ревью ожидается.
  Гейты: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **243/243**, `flutter build windows --debug` — success,
  `flutter build windows --release` — success.
- **Предыдущий этап:** stage-08 — **PASS WITH COMMENTS (0 MAJOR)**.
- **Схема БД:** **v8** без изменений.
- **ADR:** ADR-026.

## Цель

Закрыть MVP: release-сборка, Windows-инсталлятор, актуальная документация,
финальные проверки и известные ограничения.

## Что реализовано

- `installer/second_brain.iss` — Inno Setup 6.3+:
  - per-user установка в `%LOCALAPPDATA%\Programs\Second Brain` (без admin);
  - ярлыки меню «Пуск»/рабочего стола, uninstaller, запуск после установки;
  - русский/английский wizard;
  - при отсутствии MSVC runtime устанавливается `vc_redist.x64.exe`
    (скачивается build-скриптом, в git не хранится).
- `tool/build_installer.ps1` — проверяет release-бинарник, находит `ISCC.exe`,
  собирает `dist/SecondBrain-1.0.0-setup.exe`.
- CI `build-windows`: debug + release сборка, установка Inno Setup через
  Chocolatey, сборка installer, artifact `second-brain-windows`.
- `.gitignore`: `/dist/`.
- `README.md` актуализирован (статус MVP, тесты, installer, ограничения).
- `docs/RELEASE.md` — чеклист версии, гейтов, installer, smoke и публикации.
- `docs/PERFORMANCE.md` + `test/performance_smoke_test.dart` — минимальный
  perf-smoke (1000 заметок: insert 126 ms, rebuild 666 ms, FTS 7 ms локально).
- `test/release_packaging_test.dart` — проверка обязательных installer/CI
  шагов.
- ADR-026 фиксирует release/installer-решение.

## Проверки

```powershell
flutter analyze --fatal-infos   # 0 issues
flutter test                    # 243/243
flutter build windows --debug   # success
flutter build windows --release # success
flutter test test/performance_smoke_test.dart
```

Installer локально не собирался: `ISCC.exe` не установлен; CI job
`build-windows` устанавливает Inno Setup и проверяет `dist/*.exe`.
CI `44119141513` (`234fc29`) — success, artifact `second-brain-windows`
(~12 MB).

## Известные ограничения

- Installer не подписан сертификатом (SmartScreen может предупреждать);
  checksum публикуется вручную/через CI artifact digest.
- Чистый smoke установки/обновления/uninstall остаётся ручным по
  `docs/RELEASE.md`; CI проверяет компиляцию installer и наличие artifact.
- Mail.ru и live OAuth/API smoke остаются внешними ограничениями stage-06/07.
- Вложения, фильтр тегов, мультивалютная аналитика, сессии обучения/чат в FTS —
  техдолг; MVP-функции stage-08 закрыты.
- Installer проверяется в CI; локально нужен `choco install innosetup -y`.
- Smoke-тест установки/обновления выполняется вручную по `docs/RELEASE.md`.

## Ссылки

- ADR-026.
- [RELEASE.md](../RELEASE.md).
- Предыдущий этап: [stage-08.md](stage-08.md).
