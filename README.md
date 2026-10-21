# Second Brain + AI Assistant

Личное приложение-«второй мозг» с AI-ассистентом (Flutter, Windows-first,
затем iOS/Android/веб). Основное ТЗ — [PROMPT.md](PROMPT.md), этапы разработки
выполняются последовательно (Этап 0 → 10).

## Статус
- Этап 0 (каркас) — **done**; см. [docs/stages/stage-00.md](docs/stages/stage-00.md)
- Точки входа документации: [docs/INDEX.md](docs/INDEX.md), [docs/context.md](docs/context.md)
- Журнал решений: [docs/decisions.md](docs/decisions.md)

## Быстрый старт
```powershell
flutter pub get
flutter analyze          # 0 issues
flutter test             # 15 тестов
flutter run -d windows   # запустить desktop-версию
```

Для сборки `flutter build windows` требуется Visual Studio (workload
«Desktop development with C++») — см. блокеры в [docs/context.md](docs/context.md).

## Структура
```
lib/
  app/       каркас приложения (DI, роутер, темы, локализация, интеграция Windows)
  core/      сквозные сервисы (Result, ошибки, логирование, SecretStore, флаги, ApiClient)
  data/      Drift БД + репозитории
  features/  feature-first: dashboard, notes, tasks, ideas, finance,
             learning, chat, integrations, search, settings
  l10n/      ARB RU/EN + сгенерированные локализации
```
