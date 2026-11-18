# Second Brain + AI Assistant

Личное приложение-«второй мозг» с AI-ассистентом (Flutter, Windows-first,
затем iOS/Android/веб). Основное ТЗ — [PROMPT.md](PROMPT.md), этапы разработки
выполняются последовательно (Этап 0 → 10).

## Статус
- **MVP реализован:** этапы 0–9; stage-09 — полировка, тесты и Windows-инсталлятор.
- **Stage-10, первая итерация:** локальные sync-профили + backend stub,
  web-сборка (Drift WASM), CI artifact `second-brain-web`. Облако/OAuth/
  подписка пока не подключены.
- Данные локальны (SQLite/Drift), секреты — в secure storage.
- Точки входа: [docs/INDEX.md](docs/INDEX.md), [docs/context.md](docs/context.md),
  [docs/decisions.md](docs/decisions.md), [docs/tech-debt.md](docs/tech-debt.md),
  [docs/RELEASE.md](docs/RELEASE.md), [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Быстрый старт
```powershell
flutter pub get
flutter analyze --fatal-infos   # 0 issues
flutter test                    # 243 теста
flutter run -d windows
flutter run -d chrome   # web-сборка stage-10
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
