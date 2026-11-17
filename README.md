# Second Brain + AI Assistant

Личное приложение-«второй мозг» с AI-ассистентом (Flutter, Windows-first,
затем iOS/Android/веб). Основное ТЗ — [PROMPT.md](PROMPT.md), этапы разработки
выполняются последовательно (Этап 0 → 10).

## Статус
- **Реализация MVP завершена:** этапы 0–9; stage-09 — полировка, тесты и
  Windows-инсталлятор. Ожидается независимое ревью stage-09.
- Данные локальны (SQLite/Drift), секреты — в secure storage.
- Точки входа: [docs/INDEX.md](docs/INDEX.md), [docs/context.md](docs/context.md),
  [docs/decisions.md](docs/decisions.md), [docs/tech-debt.md](docs/tech-debt.md).

## Быстрый старт
```powershell
flutter pub get
flutter analyze --fatal-infos   # 0 issues
flutter test                    # 241 тест
flutter run -d windows
```

## Windows-инсталлятор
```powershell
flutter build windows --release
choco install innosetup -y      # если ISCC ещё не установлен
.\tool\build_installer.ps1
```
Готовый файл: `dist/SecondBrain-1.0.0-setup.exe`. CI (job `build-windows`)
собирает release, устанавливает Inno Setup и публикует installer-artifact
`second-brain-windows`.

## Структура
```
lib/
  app/       каркас приложения (DI, роутер, темы, локализация, Windows-интеграция)
  core/      Result, ошибки, логирование, SecretStore, ApiClient
  data/      Drift БД, репозитории, FTS, backup
  features/  dashboard, notes, tasks, ideas, finance, learning, chat,
             mail, integrations, search, analytics, settings
  l10n/      ARB RU/EN
installer/   Inno Setup script
tool/        build_installer.ps1
```

## Ограничения MVP
- Почта: Gmail и Yandex 360 (OAuth); Mail.ru отключён — нет официального
  REST-чтения, IMAP запрещён.
- Live OAuth/API-smoke не входил в локальные гейты; публичные API требуют
  сети и могут иметь rate limits.
- Вложения, фильтр тегов в поиске и мультивалютная аналитика — техдолг
  (см. `docs/tech-debt.md`).
