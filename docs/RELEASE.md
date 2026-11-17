# Windows MVP — release checklist

## 1. Version
- [ ] `pubspec.yaml` `version` обновлён (major.minor.patch+build).
- [ ] `installer/second_brain.iss` `MyAppVersion` совпадает.
- [ ] `windows/runner/Runner.rc` версия генерируется Flutter из `pubspec`.

## 2. Gates
```powershell
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter build windows --debug
flutter build windows --release
```
- [ ] analyze 0, tests green, debug/release build success.
- [ ] CI `build-windows` success, artifact `second-brain-windows` скачан.

## 3. Installer
```powershell
choco install innosetup -y   # Inno Setup >= 6.3
.\tool\build_installer.ps1  # скачает vc_redist.x64.exe при необходимости
```
- [ ] `dist/SecondBrain-<version>-setup.exe` создан.
- [ ] `vc_redist.x64.exe` не попал в git (скачивается скриптом).
- [ ] Установка в `%LOCALAPPDATA%\Programs\Second Brain` (без admin).
- [ ] Ярлыки меню «Пуск»/рабочего стола, uninstaller работают.
- [ ] Запуск после установки, данные в `%APPDATA%`/secure storage на месте.
- [ ] Обновление поверх старой версии сохраняет БД и настройки.

## 4. Smoke (ручной)
- [ ] Заметки/задачи/идеи/финансы CRUD, напоминания.
- [ ] Обучение, AI-тренер, сессия.
- [ ] Gmail/Yandex OAuth не проверялся без ключей; UI не падает.
- [ ] Поиск идей (сеть), глобальный поиск, аналитика.
- [ ] RU/EN, светлая/тёмная тема.
- [ ] JSON backup/restore, CSV export.

## 5. Публикация
- [ ] Git tag `v<version>`.
- [ ] Приложить installer к GitHub Release.
- [ ] Обновить `docs/stages/stage-09.md`, `docs/context.md`, `docs/INDEX.md`.
- [ ] Сохранить номер CI-run и checksum артефакта.

## Known limitations
См. `docs/tech-debt.md`: Mail.ru, live OAuth/API smoke, вложения, фильтр
тегов, мультивалютная аналитика, вложения/сессии в FTS.
