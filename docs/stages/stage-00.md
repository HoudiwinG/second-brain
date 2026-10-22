# Stage-00: Каркас проекта (Flutter, Windows-first)

- **Статус:** done (analyze 0 issues, test 21/21; CI [39746024266](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266) — `analyze-and-test` + `build-windows` success)
- **Дата начала / завершения (UTC):** 2026-10-21 ~16:00 — 2026-10-21 20:00
- **Основной агент:** agent-1 (DeepSeek V4.1 Flash Free / OpenCode)
- **Ревьюер:** agent-2 — ревью 2026-10-22: **FAIL**; находки R00-001…R00-012 закрыты, CI зелёный, ожидается повторное ревью

## Цель и критерии приёмки
Цель — работающий каркас приложения: Flutter-проект, структура папок,
зависимости, RU/EN-локализация, темы, роутинг, DI, БД + миграции,
secure storage, логирование, трей/горячая клавиша (Windows), тесты, CI, документация.

Критерии по STAGE_ONE.md:
1. Приложение запускается на Windows, показывает навигацию по пустым экранам —
   **код готов**; запуск GUI в окружении не выполнялся (headless-агент),
   проверено через widget-тесты.
2. Переключаются язык и тема — **выполнено** (экран Settings, widget-тест),
3. Иконка в трее и горячая клавиша работают — **код готов** (Windows-путь);
   сборка Windows подтверждена CI-job'ом `build-windows` (ADR-009),
   GUI-проверка — после локальной установки VS.
4. БД создаётся, миграции применяются — **выполнено** (интеграционный тест in-memory).
5. Analyze чистый, тесты зелёные — **выполнено** (0 issues; 21/21).
6. /docs заполнены — **выполнено** (INDEX, context, decisions + шаблоны).
7. Никаких секретов в репозитории — **выполнено** (.env.example, ключи — только в secure storage).

## Что реализовано

### Инфраструктура
- pubspec.yaml — зависимости и метаданные; version 1.0.0+1
- l10n.yaml — конфигурация генерации локализаций
- .github/workflows/ci.yml — CI: pub get + analyze --fatal-infos + test
- .env.example — шаблон окружения (без секретов)
- assets/tray_icon.png — иконка трея (сгенерирована)
- assets/tray_icon.ico — ICO 16/32 px для Windows (LoadImage не читает PNG, R00-003)
- .gitignore — шаблонный от flutter create (+ добавлены .env)

### lib/app (каркас приложения)
- main.dart — точка входа: логирование, crash-reporter, Windows-инициализация, ProviderScope
- app/app.dart — SecondBrainApp: MaterialApp.router, темы, локализация
- app/theme.dart — Material 3, ColorScheme.fromSeed, светлая/тёмная темы
- app/di.dart — провайдеры Riverpod: appDatabaseProvider (FutureProvider),
  settingsRepositoryProvider, secretStoreProvider, routerProvider
- app/router.dart — go_router StatefulShellRoute (11 веток), рельса/нижняя панель
- app/feature_directions.dart — enum FeatureBranch (контракт навигации) + иконки + метки
- app/more_screen.dart — экран «Ещё» для узких экранов
- app/widgets/placeholder_section_screen.dart — общий пустой экран фичи
- app/desktop_services.dart — window_manager (окно 900x600 min), трей (меню
  show/hide/quit), глобальная горячая клавиша Ctrl+Alt+B (открыть окно)

### lib/core (сквозные сервисы)
- core/result/result.dart — Result<T> (Success/Failure), sealed, `when`
- core/error/app_exception.dart — иерархия ошибок (Validation/Data/Network/Integration/Llm/Unexpected)
- core/logging/app_logger.dart — логгер на package:logger
- core/crash/app_crash_reporter.dart — заготовка crash-reporter (Sentry позже)
- core/network/api_client.dart — контракт единого сетевого клиента (таймауты, retry, логи); HTTP-транспорт — этап интеграций
- core/secrets/secret_store.dart — интерфейс SecretStore + фабрика ошибок
- core/secrets/secure_secret_store.dart — реализация на flutter_secure_storage
- core/secrets/in_memory_secret_store.dart — тестовая реализация
- core/flags/feature_flags.dart + app_flag.dart — реестр фича-флагов (премиум, sync, oauth, llm)
- core/crypto/crypto_service.dart — контракт шифрования чувствительных полей (реализация — stage-01+)
- core/sync/sync_service.dart — контракт облачной синхронизации + SyncStatus (реализация — stage-10)

### lib/data (инфраструктура данных)
- data/db/app_database.dart — Drift БД: таблица app_settings (key/value/updatedAt),
  schemaVersion=1, MigrationStrategy (onCreate/onUpgrade/beforeOpen с PRAGMA foreign_keys=ON),
  фабрики open() (файл в getApplicationSupportDirectory) и inMemory()
- data/db/app_database.g.dart — сгенерировано drift_dev 2.35.1
- data/repositories/settings_repository.dart — типизированный key-value доступ через Result

### lib/features — 10 фич с пустыми экранами
- dashboard, notes, tasks, ideas, finance, learning, chat, integrations, search —
  presentation/<name>_screen.dart (PlaceholderSectionScreen)
- settings/presentation/settings_screen.dart — РЕАЛЬНЫЙ экран: SegmentedButton
  для темы (system/light/dark) и языка (system/ru/en), персистентность через SettingsController
- settings/application/settings_controller.dart — AsyncNotifier: тема + язык,
  персистентность в Drift, откат при ошибках (R00-008/009)

### lib/l10n (локализация RU/EN)
- l10n/app_en.arb (template, 31 ключ), l10n/app_ru.arb
- l10n/generated/* — сгенерированные AppLocalizations

### test (21 тест)
- test/db_migration_test.dart — интеграционные тесты drift: schemaVersion=1,
  onCreate создаёт таблицу, PRAGMA foreign_keys=ON, непокрытый onUpgrade
  падает UnsupportedError (ADR-012)
- test/settings_repository_test.dart — юнит-тесты SettingsRepository
  (get/set/upsert/getOrDefault/remove/count), парсеры SettingsController,
  `SettingsState.copyWith` (сброс локали), контракт InMemorySecretStore
- test/app_router_widget_test.dart — widget-тесты: старт на дашборде,
  навигация по rail (Notes→Settings), применение темы, сброс языка на
  системный, подсветка «Ещё» для скрытых веток на узком окне
- test/helpers/in_memory_db.dart — фабрика in-memory БД

## Контракты и интерфейсы
- `SecretStore` — read/write/delete/clear через `Result` (lib/core/secrets/secret_store.dart)
- `Result<T>` + `AppException` — контракт ошибок всех слоёв (lib/core/)
- `FeatureBranch` (enum, 11 значений) — порядок веток навигации (lib/app/feature_directions.dart)
- `AppDatabase` / `AppSettings` (таблица app_settings) — схема v1 (lib/data/db/)
- `SettingsRepository` — get/getOrDefault/set/remove/count (lib/data/repositories/)
- `ApiClient` — контракт сетевого клиента; реальные вызовы — этап 3+
- `CryptoService` — encrypt/decrypt через `Result` (lib/core/crypto/)
- `SyncService` + `SyncStatus` — push/pull/status через `Result` (lib/core/sync/)
- Провайдеры Riverpod: appDatabaseProvider, settingsRepositoryProvider,
  secretStoreProvider, routerProvider, settingsControllerProvider

## Схема БД на конец этапа
- версия схемы: **1**
- таблица `app_settings`:
  - `key` TEXT PRIMARY KEY
  - `value` TEXT NOT NULL
  - `updated_at` DATETIME NOT NULL (UTC)
- индексов нет (PK по key); FTS-индексов нет (этап 1)
- миграции: onCreate → createAll(); onUpgrade — только явные ветки, без
  createAll (ADR-012); непокрытый переход падает `UnsupportedError`

## Зависимости, добавленные на этапе
runtime:
- flutter_riverpod 3.4.3 — DI/стейт (ADR-001)
- go_router 18.1.1 — навигация (ADR-005)
- drift 2.35.2 — локальная БД (ADR-002)
- sqlite3 3.x (транзитивно через drift; hooks) — нативные sqlite-бинарники.
  `sqlite3_flutter_libs` удалён как EOL-пакет (ADR-011, TD-07)
- path_provider 2.1.6 — каталог данных приложения
- flutter_secure_storage 11.2.0 — секреты (ADR-003)
- logger 2.8.0 — логирование
- flutter_localizations (sdk) + intl 0.20.3 — локализация
- window_manager 0.5.2 — окно Windows
- tray_manager 0.5.0 (пин версии, ADR-006) — трей Windows
- hotkey_manager 0.2.3 — глобальная горячая клавиша

dev:
- flutter_lints 6.0.0 — линтеры
- build_runner 2.16.2 + drift_dev 2.35.1 — кодогенерация drift

## Тесты
- 21 тест в 3 файлах (см. выше), все зелёные: `flutter test` → `All tests passed`
- Что покрывают: миграции drift (in-memory), репозиторий настроек (upsert/getOrDefault/remove),
  парсеры настроек, `SettingsState.copyWith` (сброс локали), SecretStore-контракт,
  навигация шелла, применение темы, сброс языка, подсветка нижней навигации,
  локализация EN-строк
- Что не покрыто и почему:
  - tray/hotkey — требуется реальный Windows GUI (после установки VS);
  - ApiClient — нет транспорта (этап интеграций);
  - SecureSecretStore — системное защищённое хранилище не эмулируется в тестах;
  - визуальные проверки (золотые файлы) — этап 2.

## Известные ограничения и техдолг
- Техдолг закрыт 2026-10-22 (TD-01…TD-13), принятые ограничения TD-14…TD-20 —
  в [tech-debt.md](../tech-debt.md). Кратко по ограничениям:
- Локальный `flutter build windows` требует Visual Studio C++ (ADR-007);
  в CI сборка выполняется на `windows-latest` (ADR-009, job `build-windows`).
- tray_manager 0.5.0 (пин): после установки VS / на stage-02 мигрировать на
  0.8+ nativeapi (ADR-006).
- Горячая клавиша Ctrl+Alt+B пока не настраивается пользователем — stage-02.
- Android/iOS платформы созданы заготовками flutter create; сборка их — за рамками этапа 0.
- FTS5, таблицы заметок/задач — этап 1.
- app_settings.updated_at хранится через drift DateTime (локаль при чтении — см. ADR-002).
- `onUpgrade` явно падает при отсутствии миграции: ветка v1→v2 добавляется на
  stage-01 (ADR-012).
- Трей поднимается после первого кадра и локализуется из ARB (ADR-010);
  на не-Windows платформах не инициализируется.

## Как запустить и проверить этап
```powershell
# 1. SDK установлен в C:\src\flutter и добавлен в PATH пользователя
flutter --version          # 3.47.7 stable
flutter doctor             # VS section будет красным до установки VS

# 2. Зависимости и статический анализ
flutter pub get
flutter analyze            # ожидается: No issues found!

# 3. Тесты
flutter test               # ожидается: All tests passed! (21)

# 4. Запуск приложения (Windows GUI)
flutter run -d windows     # окно с боковой панелью навигации, 11 пустых экранов,
                           # настройки: тема + язык персистентны

# 5. Сборка Windows (после установки Visual Studio C++)
flutter build windows
```

## Ссылки
- ADR: 001 (Riverpod), 002 (Drift v1), 003 (SecretStore), 004 (Result),
  005 (go_router), 006 (tray пин), 007 (build windows), 008 (структура/l10n),
  009 (CI build), 010 (трей/l10n), 011 (sqlite3), 012 (миграции)
- Техдолг: [tech-debt.md](../tech-debt.md) — закрыто TD-01…TD-13
- Ревью: [reviews/stage-00-review.md](../reviews/stage-00-review.md) — FAIL (agent-2);
  исправления подтверждены CI, ожидается повторный прогон
