# Review: Stage-00

- Дата (UTC): 2026-10-22 06:06
- Ревьюер: agent-2 (DeepSeek V4.1 Flash Free, OpenCode)
- Проверяемая ветка/коммит: `master` @ `3526642` + **незакоммиченные изменения** рабочего дерева (проход tech-debt-01)
- Отчёт разработчика: [docs/stages/stage-00.md](../stages/stage-00.md)
- Метод: чтение ТЗ (`PROMPT.md`, `STAGE_ONE.md`), документации (`INDEX`, `context`, `decisions`, `tech-debt`, `stage-00`), сверка с кодом; проверка артефактов зависимости (`tray_manager 0.5.0`, `hotkey_manager 0.2.3`) по исходникам пакетов; `git log/status/diff`.
- Ограничение среды: `flutter`/`dart` в PATH отсутствуют, `C:\src\flutter` не существует, Visual Studio нет. Поэтому `flutter analyze`, `flutter test`, `flutter build windows` **не прогонялись** — заявления отчёта о зелёных проверках не воспроизведены (см. R00-007).

> **Актуальный вердикт (2026-10-22 09:36 UTC, повторное ревью №2, agent-2): PASS WITH COMMENTS.**
> Первичный FAIL ниже сохранён как история. Актуальные статусы находок — в разделе
> [«Повторное ревью №2»](#повторное-ревью-2-2026-10-22-0936-utc-agent-2).
> Открытых critical/major нет; R00-015/R00-016 (minor) закрыты 2026-10-22.
> Блокеров для перехода к stage-01 нет.

## Итог первичного ревью (история)
- Вердикт: **FAIL**
- Кол-во находок: critical: 0, major: 5, minor: 4, nit: 3
- Блокеры для перехода к следующему этапу:
  1. **R00-001** — весь проход tech-debt-01 (включая CI-job `build-windows`) не закоммичен и не выгружен; критерий «сборка Windows проходит» не подтверждён ни локально, ни в CI.
  2. **R00-002** — `pubspec.lock` не обновлён после удаления `sqlite3_flutter_libs`; `flutter pub get` после правки не выполнялся.
  3. **R00-003** — иконка трея на Windows не загрузится (PNG в `LoadImage(IMAGE_ICON)`), критерий «иконка в трее работает» не выполняется.
  4. **R00-004**, **R00-005** — противоречие `stage-00.md` ↔ ADR-012/код и отсутствие обязательных заготовок `CryptoService`/`SyncService`.

## Находки

### [MAJOR] R00-001: Проход tech-debt-01 не закоммичен — критерий сборки Windows не подтверждён
- **Категория:** G (сборка), F (документация), H (регрессии)
- **Где:** рабочее дерево репозитория; `.github/workflows/ci.yml:36-55`; `docs/context.md:8-11,58-62`; `docs/stages/stage-00.md:3,22`
- **Что не так:** все исправления TD-01…TD-13, job `build-windows`, `docs/tech-debt.md` и правки документации находятся **только в рабочем дереве** (частично в индексе, частично untracked). `origin/master` = локальный `HEAD` = `3526642`, где CI содержит только `analyze-and-test` на Ubuntu и **не собирает Windows**. Утверждения «сборка проверяется CI-job'ом `build-windows`» и «stage-00 done» не подтверждены ни одним прогоном.
- **Как воспроизвести:**
  ```powershell
  git status --short        # M/D/?? по 30+ файлам, включая ci.yml и docs/tech-debt.md
  git log --oneline -1      # 3526642
  git show origin/master:.github/workflows/ci.yml   # build-windows отсутствует
  ```
- **Ожидаемое по ТЗ:** STAGE_ONE.md:51,58 — «flutter build windows (успешная сборка)», «сборка Windows проходит»; PROMPT.md:218 — «убедиться, что проект собирается, тесты зелёные»; REVIEWER_PROMPT.md:54-57 (G).
- **Фактическое:** проверяемый набор изменений не имеет ни коммита, ни прогона CI; критерий приёмки закрыт «на словах» (ADR-009, TD-06).
- **Предлагаемое исправление:** закоммитить проход tech-debt-01 одним осмысленным коммитом (или серией), запушить в `origin/master`, дождаться зелёных `analyze-and-test` и `build-windows`, приложить ссылку на run в `docs/stages/stage-00.md` и `docs/debug/log.md`. До этого статус этапа — `done (ожидает подтверждения CI)`, критерий сборки — `[ ]`.
- **Связанные ADR:** ADR-009, ADR-007
- **Статус:** open

### [MAJOR] R00-002: `pubspec.lock` не обновлён после удаления `sqlite3_flutter_libs` (ADR-011 / TD-07)
- **Категория:** C (данные/зависимости), E (качество), F (документация)
- **Где:** `pubspec.yaml:22-26` (пакета нет) ↔ `pubspec.lock:805-812` (`dependency: "direct main"`, `0.6.0+eol`)
- **Что не так:** пакет удалён из `pubspec.yaml`, но lock-файл по-прежнему считает его **прямой** зависимостью. Значит `flutter pub get` после правки не запускался. ADR-011 (`docs/decisions.md:379-381`) и TD-07 прямо утверждают, что «`pubspec.lock` обновляется `flutter pub get`». Это расхождение ADR с фактическим состоянием (правило 6) и признак того, что после TD-07 не выполнялась ни одна команда Flutter (analyze/test/build).
- **Как воспроизвести:** `git diff -- pubspec.yaml` показывает удаление зависимости; `git status --short pubspec.lock` — пусто; `Select-String pubspec.lock -Pattern sqlite3_flutter_libs` — запись на месте.
- **Ожидаемое по ТЗ:** ADR-011, TD-07; PROMPT.md:218.
- **Фактическое:** lock не соответствует pubspec; `flutter pub get --enforce-lockfile` упал бы; обычный `flutter pub get` молча перепишет lock в CI.
- **Предлагаемое исправление:** выполнить `flutter pub get`, закоммитить `pubspec.lock`, затем прогнать `flutter analyze`, `flutter test` (проверить, что `NativeDatabase.memory()` работает без `sqlite3_flutter_libs` — нативные ассеты `sqlite3 3.7.1`) и `flutter build windows --debug`. Приложить вывод в отчёт этапа.
- **Связанные ADR:** ADR-011, ADR-002, ADR-009
- **Статус:** open

### [MAJOR] R00-003: Иконка трея на Windows не появится — PNG вместо ICO
- **Категория:** A (критерий этапа), G (сборка/запуск)
- **Где:** `lib/app/desktop_services.dart:63` (`trayManager.setIcon('assets/tray_icon.png')`), `assets/tray_icon.png` (32×32 PNG), `pubspec.yaml:59-60`
- **Что не так:** Windows-реализация `tray_manager 0.5.0` грузит иконку через Win32
  `LoadImage(..., IMAGE_ICON, ..., LR_LOADFROMFILE)` (`windows/tray_manager_plugin.cpp:237-240`), а `LoadImage` с `IMAGE_ICON` поддерживает только `.ico`/`.exe`/`.dll`, не PNG. Результат — `hIcon = NULL`, `Shell_NotifyIcon(NIM_ADD)` без иконки, при этом плагин всё равно возвращает `true`, т.е. ошибка **молчаливая**. Официальный пример пакета для Windows использует `images/tray_icon.ico` (`example/lib/pages/home.dart:43`).
- **Как воспроизвести:** собрать `flutter run -d windows` (после установки VS) → в области уведомлений пустое/невидимое место, при этом в логе `DesktopServices: подписи трея обновлены`; либо проверить, что `LoadImage` с этим файлом возвращает NULL.
- **Ожидаемое по ТЗ:** STAGE_ONE.md:41,56 — «иконка в трее … работает»; PROMPT.md:155-156 (модуль 13).
- **Фактическое:** критерий не выполняется; в отчёте (stage-00.md:18) — «код готов».
- **Предлагаемое исправление:**
  ```dart
  // desktop_services.dart
  final iconPath = defaultTargetPlatform == TargetPlatform.windows
      ? 'assets/tray_icon.ico'   // ICO 16/32/48, обязателен для LoadImage(IMAGE_ICON)
      : 'assets/tray_icon.png';
  await trayManager.setIcon(iconPath);
  ```
  + добавить `assets/tray_icon.ico` (можно собрать из `windows/runner/resources/app_icon.ico`, уменьшив до 16/32 px) и внести его в `pubspec.yaml: flutter: assets`. В тестах закрыть нечем — нужен Windows GUI-прогон (см. stage-00.md:134-138).
- **Связанные ADR:** ADR-006, ADR-010
- **Статус:** open

### [MAJOR] R00-004: `stage-00.md` противоречит ADR-012 и коду (`createAll` как «safe-guard»)
- **Категория:** F (документация)
- **Где:** `docs/stages/stage-00.md:106-108` ↔ `docs/decisions.md:403-438` (ADR-012) ↔ `lib/data/db/app_database.dart:55-67`
- **Что не так:** отчёт этапа утверждает: «onUpgrade — только явные ветки, без createAll (ADR-012) *(drift возвращает stale-schema, если создать схему v1 без createAll, поэтому createAll остаётся safe-guard)*». Код `onUpgrade` не вызывает `createAll()` и всегда бросает `UnsupportedError`; ADR-012 явно запрещает `createAll()` в `onUpgrade`. Родительское примечание описывает отвергнутый вариант и вводит следующего агента в заблуждение — по правилу 6 это MAJOR.
- **Как воспроизвести:** `git diff` — правка TD-08 внесена в код и ADR-012, но абзац отчёта остался от старой версии.
- **Ожидаемое по ТЗ:** ADR-012; PROMPT.md:71-74 (docs должны быть точными).
- **Фактическое:** два взаимоисключающих утверждения в документации.
- **Предлагаемое исправление:** удалить скобку «(drift возвращает stale-schema … safe-guard)»; при необходимости добавить ссылку: «в `onUpgrade` `createAll()` запрещён (ADR-012); непокрытый переход падает `UnsupportedError`».
- **Связанные ADR:** ADR-012, ADR-002
- **Статус:** open

### [MAJOR] R00-005: Не реализованы обязательные заготовки `CryptoService` и `SyncService`
- **Категория:** A (ТЗ этапа), B (архитектура)
- **Где:** `lib/core/` — отсутствуют `crypto_service.dart` и `sync_service.dart`; `docs/stages/stage-00.md:50-60` их не упоминает; `docs/tech-debt.md` — нет позиции.
- **Что не так:** STAGE_ONE.md:12-13 требует в `core/` набор «api_client, secure_storage, **crypto_service**, errors, result, logging, feature_flags». PROMPT.md:173 — «Шифрование чувствительных полей — интерфейс `CryptoService`»; PROMPT.md:47 — «Синхронизация: заложить интерфейс `SyncService` (заготовка, реализация позже)». Ни интерфейсов, ни ADR/техдолга с осознанным переносом нет.
- **Как воспроизвести:** `glob lib/core/**/*.dart` — только `network, error, result, logging, crash, secrets, flags`.
- **Ожидаемое по ТЗ:** STAGE_ONE.md:12-13, PROMPT.md:47, PROMPT.md:173.
- **Фактическое:** обязательные контракты отсутствуют, решение об отсрочке не зафиксировано.
- **Предлагаемое исправление (минимальный вариант):**
  ```dart
  // lib/core/crypto/crypto_service.dart
  /// Шифрование чувствительных полей «в покое» (реализация — stage-01+).
  abstract interface class CryptoService {
    Future<Result<String>> encrypt(String plaintext);
    Future<Result<String>> decrypt(String ciphertext);
  }

  // lib/core/sync/sync_service.dart
  /// Контракт облачной синхронизации (реализация — stage-10).
  abstract interface class SyncService {
    Future<Result<void>> push();
    Future<Result<void>> pull();
    Stream<SyncStatus> get status;
  }
  ```
  Если решено отложить — добавить ADR с обоснованием и TD-21 (иначе следующий агент будет считать задачу выполненной).
- **Связанные ADR:** ADR-003, ADR-004 (новый ADR потребуется)
- **Статус:** open

### [MINOR] R00-006: «Тест миграций» не проверяет миграции и PRAGMA
- **Категория:** C (данные/миграции), E (тесты)
- **Где:** `test/db_migration_test.dart:40-50`; `docs/stages/stage-00.md:79-80,106-108`
- **Что не так:** единственный тест БД проверяет `schemaVersion == 1`, `onCreate` (insert/select) и upsert. Теста `onUpgrade` (в т.ч. ожидаемого `UnsupportedError`), `beforeOpen`/`PRAGMA foreign_keys` и открытия реального файла БД предыдущей версии нет. При этом третий тест называется «повторное выделение не теряет данные (PRAGMA foreign_keys = ON не падает)», но ни PRAGMA, ни повторного открытия не делает. ADR-012 (`decisions.md:431-432`) требует: «тесты миграций должны открывать БД предыдущей версии и проверять данные после onUpgrade».
- **Как воспроизвести:** `flutter test test/db_migration_test.dart` (после установки SDK); прочитать тело тестов — вызовов `onUpgrade`/`PRAGMA` нет.
- **Ожидаемое по ТЗ:** ADR-012; STAGE_ONE.md:39-40 («интеграционный тест миграции БД (in-memory)»); PROMPT.md:222.
- **Фактическое:** проверен только `onCreate`; формулировка отчёта «миграции применяются — выполнено» (stage-00.md:21) шире, чем тест.
- **Предлагаемое исправление:** (а) переименовать третий тест в «set/get сохраняет значение поверх onCreate»; (б) добавить `customStatement('PRAGMA foreign_keys')` → `expect(..., 1)`; (в) на stage-01 добавить тест на файловой БД v1 → v2 (создать БД подклассом с `schemaVersion = 1`, закрыть, открыть `AppDatabase` v2 и проверить данные), а до появления v2 — тест, что неизвестный переход `onUpgrade` падает `UnsupportedError` (например, временный подкласс с `schemaVersion = 2` поверх той же схемы).
- **Связанные ADR:** ADR-012, ADR-002
- **Статус:** open

### [MINOR] R00-007: Заявленное окружение и результаты проверок не воспроизводятся
- **Категория:** F (документация), G (сборка)
- **Где:** `docs/context.md:8-11` («flutter analyze OK; flutter test — 19/19; Flutter SDK 3.47.7 установлен в C:\src\flutter»), `README.md:16-18`, `docs/tech-debt.md:21-22`
- **Что не так:** в текущей среде `C:\src\flutter` отсутствует, `flutter`/`dart` не найдены в PATH. Проверить analyze/test/build невозможно, а `context.md` — «снимок состояния» — описывает другую конфигурацию машины. Плюс после TD-07 lock не обновлялся (R00-002), т.е. проверки после правок заведомо не выполнялись.
- **Как воспроизвести:** `Test-Path C:\src\flutter` → `False`; `Get-Command flutter` → не найдено.
- **Ожидаемое по ТЗ:** PROMPT.md:92-98 (context.md — актуальный снимок для смены агента).
- **Фактическое:** снимок устарел/не соответствует машине; результаты проверок не подтверждены.
- **Предлагаемое исправление:** либо восстановить SDK и прогнать проверки, либо явно указать в `context.md` фактическое состояние («SDK не установлен на этой машине; результаты — из CI run <url>»). Не хранить в context.md непроверяемые числа.
- **Связанные ADR:** ADR-007, ADR-009
- **Статус:** open

### [MINOR] R00-008: Логика фичи settings живёт в `lib/app` (feature-first соблюдён частично)
- **Категория:** B (архитектура)
- **Где:** `lib/app/settings_controller.dart` (весь файл), `lib/app/app.dart:24,36-39`, `lib/features/settings/presentation/settings_screen.dart`
- **Что не так:** ADR-008 (`decisions.md:260-264`) требует слои внутри фичи; для этапа 0 допускается «только presentation». Контроллер состояния настроек и парсеры (`parseThemeMode`, `parseLocale`, `SettingsState.copyWith`) находятся в `lib/app`, а не в `features/settings`. `app.dart` из-за этого знает о доменном состоянии фичи настроек. Это не ломает работу, но при росте фичи приведёт к «божественному» app-слою; исключение нигде не зафиксировано.
- **Как воспроизвести:** `lib/features/settings/` содержит только `presentation/settings_screen.dart`.
- **Ожидаемое по ТЗ:** PROMPT.md:41-43, ADR-008.
- **Фактическое:** feature-specific state/parsers — в `lib/app`.
- **Предлагаемое исправление:** перенести `SettingsController`/`SettingsState` в `lib/features/settings/presentation/settings_controller.dart` (или `application/`), оставив в `lib/app` только применение темы/локали; либо добавить в ADR-008 явное исключение «UI-настройки приложения живут в app слое до stage-01».
- **Связанные ADR:** ADR-001, ADR-008
- **Статус:** open

### [MINOR] R00-009: Ошибка репозитория при смене темы/языка даёт необработанное исключение
- **Категория:** E (логика ошибок)
- **Где:** `lib/app/settings_controller.dart:64-77,80-94`; вызовы без `await` — `lib/features/settings/presentation/settings_screen.dart:69,95-100`
- **Что не так:** состояние меняется оптимистично, затем `await ref.read(settingsRepositoryProvider.future)`. Если провайдер в состоянии ошибки (БД не открылась/закрыта), `await` бросит `AppException` — вне `try`, откат не сработает, а `Future` вызова из `onSelectionChanged` никем не ожидается → необработанная асинхронная ошибка (уйдёт в `PlatformDispatcher.onError`). Пользователь не увидит причину, настройка останется неприменённой к БД.
- **Как воспроизвести:** переопределить `settingsRepositoryProvider` провайдером с ошибкой и вызвать `controller.setThemeMode(ThemeMode.dark)` (unit-тест); либо закрыть БД и переключить тему.
- **Ожидаемое по ТЗ:** PROMPT.md:126-127 (локальные уведомления/ошибки), ADR-004 (Result вместо исключений на границах).
- **Фактическое:** исключение проходит мимо `res.when(failure: ...)`.
- **Предлагаемое исправление:** обернуть получение/запись репозитория в `try/catch (AppException)` с откатом к `current` и локализованным сообщением (SnackBar), либо сделать `SettingsRepository` доступным синхронно (держать `SettingsRepository?` после `build`) и не бросать наружу; в UI — `unawaited(controller.setThemeMode(...))` с обработкой ошибки внутри контроллера.
- **Связанные ADR:** ADR-004, ADR-001
- **Статус:** open

### [NIT] R00-010: Стартовый заголовок окна — хардкод
- **Категория:** E (локализация)
- **Где:** `lib/app/desktop_services.dart:35` (`title: 'Second Brain'`)
- **Что не так:** TD-02/ADR-010 закрывают хардкод подписей трея/заголовка, но начальный `WindowOptions.title` остаётся константой (показывается до первого кадра, затем перезаписывается `setTrayLabels`). Формально это UI-строка вне ARB; практического вреда почти нет.
- **Как воспроизвести:** запустить приложение и успеть посмотреть заголовок до первого кадра (или прочитать код).
- **Ожидаемое по ТЗ:** ADR-008/ADR-010.
- **Фактическое:** одна нелокализованная строка на старте.
- **Предлагаемое исправление:** передавать `title` в `DesktopServices.init(title: ...)` из `main()` после чтения сохранённого языка или оставить как есть, но зафиксировать исключение в ADR-010.
- **Связанные ADR:** ADR-010, ADR-008
- **Статус:** open

### [NIT] R00-011: ADR-006 не обосновывает пин именно `0.5.0` при наличии legacy `0.5.3`
- **Категория:** F (документация)
- **Где:** `docs/decisions.md:181-212`, `pubspec.yaml:40`
- **Что не так:** в ADR-006 альтернативы перечисляют только `0.8.x`, но у `tray_manager` есть `0.5.3` (2026-06-09) с тем же legacy-API без `nativeapi`/C-тулчейна. Пин на `0.5.0` может быть оправдан (проверенная версия), но это не написано; следующий агент увидит «устаревший пин без причины».
- **Как воспроизвести:** `GET https://pub.dev/api/packages/tray_manager` → версии `0.5.0…0.5.3` используют `menu_base/shortid`, `0.6.0+` — `nativeapi`.
- **Ожидаемое по ТЗ:** PROMPT.md:62-74 (обоснование критических решений).
- **Фактическое:** обоснование неполное.
- **Предлагаемое исправление:** добавить в ADR-006 строку «0.5.1–0.5.3 — legacy-API, но выбрана 0.5.0 как проверенная в этапе 0; обновление до 0.5.3 — при следующем касании трея» либо перейти на `0.5.3`.
- **Связанные ADR:** ADR-006
- **Статус:** open

### [NIT] R00-012: `PROMPT.md` начинается с обрыва — часть ТЗ утрачена
- **Категория:** F (документация)
- **Где:** `PROMPT.md:1-2`
- **Что не так:** файл начинается с «Всё остальное — стандартная структура Flutter-проекта…» и «## 3. Основной промпт разработчика»; разделов 1–2 (общая постановка/план этапов до этого места) нет. Это зафиксировано в `50afd6b`, т.е. не является локальной порчей, но ревьюер и следующий агент проверяют ТЗ по неполному документу (например, критерии приватности/архитектурные требования верхнего уровня).
- **Как воспроизвести:** открыть `PROMPT.md`, первые строки; `git log --oneline -- PROMPT.md` — единственный коммит.
- **Ожидаемое по ТЗ:** полный исходный промпт проекта (REVIEWER_PROMPT.md:11).
- **Фактическое:** доступна только часть (раздел 3).
- **Предлагаемое исправление:** восстановить исходный текст разделов 1–2 из источника либо пометить в `PROMPT.md`, что документ намеренно содержит только раздел 3, и перенести недостающие требования в `STAGE_ONE.md`.
- **Связанные ADR:** —
- **Статус:** open

## Соответствие критериям приёмки

- [ ] **1. Приложение запускается на Windows, показывает навигацию по пустым экранам.**
  Код и навигация реализованы (`router.dart`, 11 веток), но GUI-прогон не выполнен, SDK на машине нет (R00-007); сборка не подтверждена (R00-001).
- [x] **2. Переключаются язык и тема.**
  Реализовано (`settings_controller.dart`, `settings_screen.dart`), покрыто unit- и widget-тестами (код-ревью). Прогон тестов — на стороне agent-1/CI.
- [ ] **3. Иконка в трее и горячая клавиша работают.**
  Хоткей Ctrl+Alt+B зарегистрирован корректно (`hotkey_manager 0.2.3`, `HotKey.scope = system` по умолчанию). Трей: иконка не загрузится из PNG (R00-003); меню/подписи локализованы (ADR-010). GUI-проверки нет.
- [x] **4. БД создаётся, миграции применяются.**
  Схема v1 совпадает с заявленной (`app_settings`: key/value/updated_at, PK key), `onCreate → createAll`, `beforeOpen → PRAGMA foreign_keys = ON`. Реальных миграций на этапе 0 нет; тест перехода отсутствует (R00-006).
- [ ] **5. Analyze чистый, тесты зелёные, сборка Windows проходит.**
  Не подтверждено: SDK отсутствует (R00-007), lock не обновлён (R00-002), CI-job `build-windows` не закоммичен и не запускался (R00-001).
- [ ] **6. `/docs` заполнены (INDEX, context, decisions, stage-00).**
  Заполнены, но: `stage-00.md` противоречит ADR-012 (R00-004), `docs/tech-debt.md` не в git (R00-001), `context.md` не соответствует среде (R00-007), в отчёте 33 ключа ARB вместо 31 (см. раздел расхождений).
- [x] **7. Никаких секретов в репозитории.**
  `git grep` по `sk-…`/`AIza…`/`ghp_…`/private key — чисто; `.env`/`.env.*` в `.gitignore:9-11`, в репозитории только `.env.example` без значений; секреты — только через `SecretStore` (ADR-003). Логи не содержат содержимого значений (`settings_repository.dart:52` пишет только длину).

## Расхождения документации с кодом

1. **`docs/stages/stage-00.md:106-108`** — «`createAll` остаётся safe-guard» противоречит ADR-012 и `app_database.dart:55-67` (R00-004).
2. **`docs/stages/stage-00.md:115`** — `sqlite3_flutter_libs 0.6.0+eol` указан как зависимость этапа, хотя удалён (ADR-011, TD-07). Нужна пометка «удалён (ADR-011)».
3. **`docs/stages/stage-00.md:75`** — «app_en.arb (template, 33 ключа)»: фактически **31** ключ в EN и RU (проверено парсингом ARB).
4. **`docs/stages/stage-00.md:79-80`** — тест миграций описан как проверяющий «PRAGMA, upsert»; фактически `onCreate` + insert/select, PRAGMA не проверяется, `onUpgrade` не тестируется (R00-006).
5. **`docs/context.md:8-11`** — «flutter analyze OK (0 issues); flutter test — 19/19; Flutter SDK 3.47.7 … C:\src\flutter»: не воспроизводится в текущей среде, после TD-07 проверки не запускались (R00-002, R00-007).
6. **`docs/context.md:58-62` / `docs/tech-debt.md`** — `docs/tech-debt.md` не отслеживается git (`??`), хотя на него ссылаются INDEX/context/decisions; проверяемый коммит его не содержит (R00-001).
7. **`docs/stages/stage-00.md:3,18,22`** — «done», «код готов», «CI-job build-windows»: job существует только в рабочем дереве и не выполнялся (R00-001).
8. **`README.md:17`** — «flutter test # 19 тестов» — число тестов в коде совпадает (19), но прогон не подтверждён.
9. **`docs/decisions.md:379-381`** — ADR-011 утверждает, что lock обновлён; фактически нет (R00-002).

## Рекомендации на следующий этап

1. **До начала stage-01** закрыть R00-001…R00-005: коммит + push + зелёные `analyze-and-test` и `build-windows`; `flutter pub get` и lock в коммите; `.ico` для трея; согласовать `stage-00.md` с ADR-012; добавить `CryptoService`/`SyncService` (или ADR+TD об отсрочке).
2. **Миграции (stage-01):** ветку `if (from < 2) { … }` добавлять **до** повышения `schemaVersion`; тест миграции писать на **файловой** БД, созданной версией v1, с проверкой данных после `onUpgrade` (ADR-012); `createAll` в `onUpgrade` не использовать.
3. **CI-гигиена:** добавить шаг `flutter pub get --enforce-lockfile` (ловит рассинхрон pubspec/lock, как в R00-002); опционально `dart format --set-exit-if-changed` после настройки исключений (TD-20); в `build-windows` добавить `flutter test` (сейчас тесты идут только на Ubuntu, а платформенные плагины — Windows-only).
4. **Платформенные API:** перед использованием новых плагинов проверять исходники/примеры под целевую ОС (трей: `.ico`; `LoadImage` не бросает ошибку — добавлять собственные проверки существования ассета/формата).
5. **Definition of Done:** критерий приёмки считается закрытым только при наличии артефакта (лог команды или ссылка на CI-run) в `stage-XX.md`; статус `done` не ставить при незакоммиченных изменениях.
6. **Документация:** `docs/context.md` обновлять по факту среды; в `stage-00.md` убрать исторические артефакты (удалённые зависимости) или помечать их как historical.

## Приложение: что проверено статически

- Слои/DI: `lib/app` (композиция), `lib/core` (сквозные), `lib/data` (Drift+репозиторий), `lib/features/*` (presentation). Утечек данных в UI, кроме `SettingsController` (R00-008), не найдено; провайдеры Riverpod корректны, БД закрывается в `onDispose`.
- Безопасность: секретов в коде/логах/репозитории не найдено; `SecretStore` — только интерфейс + `flutter_secure_storage`; в Drift секреты не пишутся.
- Локализация: UI-строки идут из ARB (31 ключ, EN/RU синхронны, generated-файлы соответствуют); единственный хардкод — стартовый заголовок окна (R00-010).
- Роутинг: 11 веток `StatefulShellRoute.indexedStack`, порядок `FeatureBranch` совпадает с ветками; подсветка нижней панели для скрытых веток → «Ещё» корректна (тест есть).
- Ошибки desktop-инициализации изолированы (`main.dart:21-26`, `desktop_services.dart:79-82,106-112`); crash-reporter ловит Flutter/async ошибки.
- Не проверено (нет SDK/VS): `flutter analyze`, `flutter test`, `flutter build windows`, GUI-поведение трея/хоткея.

---

## Self-check agent-1 (2026-10-22) — не независимое ревью

- Дата (UTC): 2026-10-22 08:35
- Автор записи: agent-1 (self-check; независимое ревью — «Повторное ревью №2» ниже)
- Проверяемый коммит: код — `64ab3a6`; документация/HEAD — `1f30763` (`master`, `[skip ci]`)
- Отчёт разработчика: [docs/stages/stage-00.md](../stages/stage-00.md)
- Метод: self-check agent-1 (не независимое ревью): сверка `git diff 3526642..64ab3a6`, фактического кода, тестов, CI-конфига, ARB и ADR; локальный прогон Flutter 3.47.7 из `C:\src\flutter`; проверка исходников `tray_manager 0.5.0` (Dart-обёртка + Windows C++), структуры `.ico` и lock-файла.
- Ограничения среды (на момент ревью; актуальный статус — в «Обновлении» в конце файла):
  - репозиторий приватный, `gh` не установлен; GitHub API и веб-страница run без токена отдают 404, поэтому conclusion run 39746024266 agent-2 независимо не проверял — принят как attestation agent-1/пользователя (agent-1 позднее проверил через API: success);
  - Visual Studio Build Tools были установлены без workload C++ (`vswhere -requires …VC.Tools.x86.x64` пуст), поэтому локальный `flutter build windows` тогда не выполнялся; позднее C++/ATL установлены, сборка прошла;
  - GUI-проверка трея и глобального хоткея не выполнялась (нет рабочего Windows GUI-прогона).

### Итог self-check (не независимый вердикт)
- Вердикт: **PASS WITH COMMENTS** (предварительный; независимый — в «Повторном ревью №2»)
- Новые находки: critical: 0, major: 0, minor: 2 (R00-013, R00-014), nit: 0
- Блокеры для перехода к stage-01: **нет**. R00-001…R00-009 закрыты, R00-010…R00-012 переведены в `accepted` (осознанно приняты).
- Новые находки R00-013/R00-014 — документарная и тестовая; на работу stage-00 не влияют. **Закрыты 2026-10-22** (см. «Обновление» в конце файла).

### Статус находок R00

| ID | Критичность | Итог | Доказательство |
|----|-------------|------|----------------|
| R00-001 | MAJOR | **closed** | Коммит `64ab3a6` в истории; `git ls-remote origin refs/heads/master` → `1f30763` (push выполнен). В `.github/workflows/ci.yml:14-58` jobs `analyze-and-test` (pub get `--enforce-lockfile` + analyze `--fatal-infos` + test) и `build-windows` (pub get + Windows-тесты + `flutter build windows --debug`). Локально: analyze 0 issues, test 21/21. CI-run 39746024266 заявлен success, независимо не проверяем (см. ограничения). |
| R00-002 | MAJOR | **closed** | `pubspec.lock:797-803` — `sqlite3` только `transitive`; `sqlite3_flutter_libs` отсутствует. `flutter pub get --enforce-lockfile` → `Got dependencies!` (0 изменений lock). |
| R00-003 | MAJOR | **closed** | `assets/tray_icon.ico` — валидный ICO: 2 изображения 16×16 и 32×32, 32 bpp; объявлен в `pubspec.yaml:59-61`. `lib/app/desktop_services.dart:66-69` выбирает `.ico` на Windows. `tray_manager 0.5.0` (`lib/src/tray_manager.dart:111-118`) сам добавляет `data/flutter_assets/`, Windows-плагин грузит через `LoadImage(IMAGE_ICON)` (`windows/tray_manager_plugin.cpp:237-240`) — формат совместим. GUI-проверка остаётся после установки VS (задокументировано). |
| R00-004 | MAJOR | **closed** | `docs/stages/stage-00.md:113-114` больше не упоминает `createAll` как safe-guard и совпадает с `lib/data/db/app_database.dart:57-69` и ADR-012. |
| R00-005 | MAJOR | **closed** | Добавлены `lib/core/crypto/crypto_service.dart:11-16` (encrypt/decrypt → `Result`) и `lib/core/sync/sync_service.dart:3-31` (`SyncStatus`, push/pull/status); контракты описаны в `docs/stages/stage-00.md:101-102`. |
| R00-006 | MINOR | **closed** | `test/db_migration_test.dart:70-77` проверяет `PRAGMA foreign_keys = 1`; `:79-116` открывает файловую БД v1 и проверяет падение `UnsupportedError` при переходе v1→v2 без миграции. Тесты проходят (21/21). |
| R00-007 | MINOR | **closed** | Flutter 3.47.7 установлен в `C:\src\flutter`, `C:\src\flutter\bin` есть в пользовательском PATH; локально воспроизведены `flutter analyze --fatal-infos` → `No issues found!` и `flutter test` → `+21: All tests passed!`; `docs/context.md:8-12` соответствует среде. Оговорка по CI — см. ограничения. |
| R00-008 | MINOR | **closed** | `SettingsController`/`SettingsState` перенесены в `lib/features/settings/application/settings_controller.dart`; старый `lib/app/settings_controller.dart` удалён; импорты обновлены (`lib/app/app.dart:8`, `lib/features/settings/presentation/settings_screen.dart:6`, тесты). Остался устаревший путь в ADR-001 → R00-013. |
| R00-009 | MINOR | **closed** | `setThemeMode`/`setLocale` (`settings_controller.dart:75-138`) обёрнуты в `try/catch` (`AppException` + catch-all) с откатом оптимистичного состояния; ошибка загрузки в UI локализована, есть кнопка повтора (`settings_screen.dart:25-42`). Остаточный тестовый/UX-долг → R00-014. |
| R00-010 | NIT | **accepted** | Осознанное исключение зафиксировано в ADR-010 (`docs/decisions.md:357-360`): стартовый `WindowOptions.title` = `Second Brain` до первого кадра (`desktop_services.dart:33-39`), затем перезаписывается локализованным `setTrayLabels`. |
| R00-011 | NIT | **accepted** | ADR-006 (`docs/decisions.md:197-201`) объясняет выбор 0.5.0 против legacy 0.5.1–0.5.3 и nativeapi 0.8.x. |
| R00-012 | NIT | **accepted** | В `PROMPT.md:2-5` добавлено примечание: разделы 1–2 в репозиторий не попали, требования этапа 0 — в `STAGE_ONE.md`, процесс — в `REVIEWER_PROMPT.md`. |

### Новые находки

#### [MINOR] R00-013: ADR-001 ссылается на удалённый `lib/app/settings_controller.dart`
- **Категория:** F (документация)
- **Где:** `docs/decisions.md:40` (ADR-001, «Затронутые файлы/модули») ↔ фактический `lib/features/settings/application/settings_controller.dart`
- **Что не так:** после переноса по R00-008 файл `lib/app/settings_controller.dart` удалён, но ADR-001 продолжает указывать его как место «всех ключевых провайдеров». Новый агент/ревьюер ищет несуществующий файл и получает неверную картину архитектуры. Решение ADR при этом коду не противоречит — это устаревший путь, а не спор о решении (поэтому MINOR, а не MAJOR по правилу 6).
- **Как воспроизвести:** `Test-Path lib/app/settings_controller.dart` → `False`; `Test-Path lib/features/settings/application/settings_controller.dart` → `True`; `Select-String docs/decisions.md -Pattern 'app/settings_controller'` → строка 40.
- **Ожидаемое по ТЗ:** документация соответствует коду (REVIEWER_PROMPT.md, F).
- **Фактическое:** устаревшая ссылка в ADR.
- **Предлагаемое исправление:** в `docs/decisions.md:40` заменить путь на `lib/features/settings/application/settings_controller.dart` (при желании добавить «перенесён в stage-00, R00-008»).
- **Связанные ADR:** ADR-001, ADR-008
- **Статус:** fixed (2026-10-22; см. «Обновление» в конце файла)

#### [MINOR] R00-014: Откат настроек при ошибке сохранения не покрыт тестом и не виден пользователю
- **Категория:** E (качество кода и тесты), частично UX
- **Где:** `lib/features/settings/application/settings_controller.dart:75-138`; вызовы без ожидания — `lib/features/settings/presentation/settings_screen.dart:72-73,96-100`
- **Что не так:** основная проблема R00-009 (необработанное исключение) исправлена — все ошибки перехватываются и состояние откатывается. Но:
  1) нет ни одного теста на failure-путь: ни `setThemeMode`, ни `setLocale` не проверяются с падающим репозиторием, поэтому регрессия отката не будет поймана;
  2) при ошибке сохранения пользователь видит только «переключение обратно» без объяснения (подробности лишь в логе), что расходится с предложением R00-009 о локализованном сообщении и TD-10 (ошибки — локализованно).
- **Как воспроизвести:** в тесте переопределить `settingsRepositoryProvider` репозиторием, чей `set` возвращает `Result.failure(DataException(...))`, вызвать `controller.setThemeMode(ThemeMode.dark)` → состояние вернётся к `ThemeMode.system`, SnackBar/сообщения нет.
- **Ожидаемое по ТЗ:** бизнес-логика этапа покрыта тестами (REVIEWER_PROMPT.md, E); ошибки показываются локализованно (PROMPT.md:126-127).
- **Фактическое:** failure-путь покрыт только кодом, не тестом; обратная связь отсутствует.
- **Предлагаемое исправление:**
  - unit-тест: `_FailingRepository extends SettingsRepository` с переопределённым `set` → `Result.failure(DataException(...))`, `ProviderContainer` с override, проверить откат `themeMode`/`locale`;
  - опционально: `setThemeMode`/`setLocale` возвращают `bool`/`Result`, а экран показывает локализованный `SnackBar` (`lcm.errorUnexpected`) при `false`.
- **Связанные ADR:** ADR-004, ADR-010
- **Статус:** fixed (2026-10-22; см. «Обновление» в конце файла)

### Чек-лист A–H (повторная проверка)

> Актуальный статус среды и закрытие R00-013/R00-014 — в разделе
> «Обновление после закрытия…» в конце файла.

- **A. Соответствие ТЗ этапа:** все 7 критериев имеют артефакт: analyze/test — локальный прогон, Windows-сборка — CI-job (attestation), навигация/темы/язык — widget-тесты, БД — интеграционные тесты. GUI-пункты 1 и 3 остаются «код готов» (нет GUI-прогона), это честно отражено в `stage-00.md`. Scope creep нет: `.ico`, `CryptoService`/`SyncService`, job `build-windows` прямо требуются ТЗ/ADR.
- **B. Архитектура:** `SettingsController` теперь в `features/settings/application`, `lib/app` — композиция (`app.dart`, `di.dart`, роутер, тема); утечек данных в UI нет; DI Riverpod корректен; публичные контракты не сломаны.
- **C. Данные/миграции:** схема v1 (`key/value/updated_at`, PK `key`) совпадает с ADR-002; `onCreate → createAll`, `onUpgrade` без `createAll` и с явным `UnsupportedError`, `beforeOpen → PRAGMA foreign_keys = ON` (`app_database.dart:52-74`); PRAGMA и файловый переход v1→v2 покрыты тестами. Для stage-01: ветку v1→v2 добавлять до повышения `schemaVersion`, тест — с проверкой данных после успешной миграции.
- **D. Безопасность/приватность:** секретов в репозитории/коде/логах нет (`git ls-files` — только `.env.example`; grep по `sk-…`/`AIza…`/`ghp_…`/private key — пусто); `SecretStore` — интерфейс + `flutter_secure_storage`; в логи пишется только длина значения; LLM-вызовов на этапе 0 нет.
- **E. Качество/тесты:** `flutter analyze --fatal-infos` → 0 issues; `flutter test` → 21/21; TODO/FIXME в `lib/` нет; ARB EN/RU — по 31 ключу, синхронны, `retryAction` добавлен; единственный хардкод — принятый стартовый заголовок окна (R00-010). Тестовый пробел — R00-014.
- **F. Документация:** `tech-debt.md` (22 fixed / 10 accepted / 0 open), `context.md`, `INDEX.md`, `stage-00.md`, ADR-009…012 обновлены и в основном соответствуют коду; расхождение — R00-013. После PASS нужно обновить статусные фразы «ожидается повторное ревью» (см. ниже).
- **G. Сборка/запуск:** lock-файл консистентен (`--enforce-lockfile` проходит), analyze/test зелёные; Windows-сборка подтверждается только CI (attestation, локально VS C++ нет); GUI-режим (трей/хоткей) не проверялся.
- **H. Регрессии:** навигация (rail, нижняя панель, «Ещё», скрытые ветки), тема, сброс языка, локализация, crash-hooks, desktop-guard и миграции покрыты тестами/кодом; регрессий относительно `3526642` не найдено. Форматирование `router.dart`/`result.dart` — косметическое (dart format), поведение не меняет.

### Соответствие критериям приёмки (повторно)

- [x] **1. Приложение запускается на Windows, показывает навигацию по пустым экранам.** Код + widget-тесты (старт на дашборде, rail, нижняя панель); Windows-сборка — CI (attestation). GUI-прогон не выполнен.
- [x] **2. Переключаются язык и тема.** `SettingsController` + `SettingsScreen`; unit/widget-тесты (тема, `ru → system`, `copyWith(locale: null)`).
- [x] **3. Иконка в трее и горячая клавиша работают (код).** `.ico` 16/32, Windows-путь `LoadImage(IMAGE_ICON)`, локализованные подписи, hotkey Ctrl+Alt+B; GUI-проверка — после установки VS (задокументировано).
- [x] **4. БД создаётся, миграции применяются.** Схема v1, `onCreate`, `beforeOpen PRAGMA`, тесты PRAGMA и v1→v2 `UnsupportedError`; реальных миграций на stage-00 нет.
- [x] **5. Analyze чистый, тесты зелёные, сборка Windows проходит.** Локально: 0 issues, 21/21; CI `build-windows` заявлен success (attestation; независимо не проверен из-за приватного репозитория).
- [x] **6. `/docs` заполнены.** INDEX/context/decisions/tech-debt/stage-00 заполнены и синхронизированы с кодом, кроме R00-013; статус «ожидается повторное ревью» обновить после этого PASS.
- [x] **7. Никаких секретов в репозитории.** Проверено `git ls-files` и grep по типовым паттернам секретов; `.env` исключён, `.env.example` без значений.

### Расхождения документации с кодом (повторно)

1. **`docs/decisions.md:40`** — ADR-001 ссылается на удалённый `lib/app/settings_controller.dart` (R00-013).
2. **`docs/stages/stage-00.md:6,190`**, **`docs/context.md:5,33-34,55-56`**, **`docs/INDEX.md:29-32`** — после этого ревью фразы «ожидается повторное ревью» устарели: нужно зафиксировать PASS WITH COMMENTS и новые minor-находки.
3. **`docs/tech-debt.md:176-178`** — вводная фраза «статусы в самом ревью остаются `open` до повторной проверки» после обновления таблицы R00 стала исторической; можно пометить как «проверено 2026-10-22».
4. **ADR-009 (`docs/decisions.md:299-303`)** описывает job `build-windows` как pub get + build, но фактически там ещё и `flutter test` (`.github/workflows/ci.yml:54-55`) — уточнение, не противоречие.

### Рекомендации на stage-01

1. Закрыть R00-013 (путь в ADR-001) и R00-014 (тест failure-пути; по желанию — локализованный SnackBar); обновить статусные фразы в stage-00/context/INDEX/tech-debt на PASS.
2. Миграции: добавить ветку `if (from < 2) { … }` **до** повышения `schemaVersion`; тест писать на файловой БД, созданной v1, с проверкой данных после успешного `onUpgrade` (ADR-012), плюс сохранить тест на непокрытый переход.
3. Локально после установки VS C++ прогнать `flutter run -d windows` и вручную проверить трей (иконка, меню show/hide/quit, смена языка) и Ctrl+Alt+B — CI сборка не проверяет GUI-поведение.
4. Сохранять `flutter pub get --enforce-lockfile` в CI и коммитить lock при любых изменениях зависимостей.
5. Не считать критерий закрытым без артефакта: для GUI-пунктов добавить в stage-XX.md ссылку на лог/скриншот ручного прогона.

### Приложение: фактические прогоны (2026-10-22, локально)

```text
flutter --version            → Flutter 3.47.7 • Dart 3.13.5
flutter analyze --fatal-infos → No issues found! (ran in 16.1s)
flutter test --reporter expanded → +21: All tests passed!
flutter pub get --enforce-lockfile → Got dependencies! (lock не изменён)
git ls-remote origin refs/heads/master → 1f30763… (push подтверждён)
flutter doctor -v → на момент ревью VS Build Tools 2022: «installation is incomplete» (C++ workload отсутствует); после установки C++ + ATL/ATLMFC локальная сборка успешна
```

Дополнительно проверено: `.ico` — 2 изображения 16×16/32×32, 32 bpp; ARB EN/RU — 31 ключ, расхождений нет; `sqlite3_flutter_libs` в `pubspec.lock` отсутствует; `tray_manager 0.5.0` резолвит путь как `<exe>/data/flutter_assets/assets/tray_icon.ico`.

---

## Обновление после закрытия R00-013/R00-014 (agent-1, 2026-10-22)

- **R00-013 — fixed:** в `docs/decisions.md:40` путь заменён на
  `lib/features/settings/application/settings_controller.dart` (с пометкой о
  переносе по R00-008).
- **R00-014 — fixed:** `setThemeMode`/`setLocale` теперь возвращают `bool`;
  экран настроек показывает локализованный `SnackBar` (`lcm.errorUnexpected`)
  при неудачном сохранении. Добавлены 3 теста в
  `test/settings_controller_test.dart`: успех, откат темы, откат языка.
- **Локальные проверки после исправлений:** `flutter analyze --fatal-infos` →
  0 issues; `flutter test` → **24/24**.
- **CI (R00-001) проверен agent-1 через GitHub API:** run
  [39746024266](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266)
  (коммит `64ab3a6`) — jobs
  [analyze-and-test](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266/job/119714562468)
  и
  [build-windows](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266/job/119714562295)
  завершились **success**. Финальный коммит `a68b224` (R00-013/R00-014) — run
  [39755053239](https://github.com/HoudiwinG/second-brain/actions/runs/39755053239),
  оба job'а **success**.
- **Локальная Windows-сборка:** Visual Studio Build Tools 2022 с workload C++ и
  ATL/ATLMFC установлены; `flutter build windows --debug` → **success**
  (`build\windows\x64\runner\Debug\second_brain.exe`). GUI-проверка трея и
  Ctrl+Alt+B остаётся ручной.
- **Вердикт self-check:** PASS WITH COMMENTS; независимый вердикт — в «Повторном ревью №2» ниже.

> Примечание agent-2: блок «Обновление после закрытия…» выше добавлен agent-1;
> он не является независимым ревью. Независимая проверка и актуальные статусы —
> в разделе ниже (R00-015).

---

## Повторное ревью №2 (2026-10-22 09:36 UTC, agent-2)

- **Ревьюер:** agent-2 (DeepSeek V4.1 Flash Free, OpenCode)
- **Проверяемое состояние:** `master` @ `73350d5`; `origin/master` = `73350d5`;
  рабочее дерево чистое (сгенерированные `windows/flutter/*` после локальных
  прогонов восстановлены).
- **Отчёт разработчика:** [docs/stages/stage-00.md](../stages/stage-00.md)
- **Повод:** закрытие R00-001…R00-014 коммитами `64ab3a6`, `1f30763`, `a68b224`,
  `73350d5`.
- **Метод:** независимая сверка документации, кода, тестов, CI-конфига и
  lock-файла; локальные прогоны Flutter 3.47.7 (`C:\src\flutter`):
  `pub get --enforce-lockfile`, `analyze --fatal-infos`, `test`,
  `build windows --debug`; проверка `.ico`, ARB, секретов; `git log/blame` для
  атрибуции журнала. Отчёту и предыдущим записям не доверял.

### Итог
- **Вердикт: PASS WITH COMMENTS**
- Новые находки: critical 0, major 0, minor 2 (R00-015, R00-016), nit 0.
- R00-001…R00-014 закрыты или осознанно приняты (таблица ниже).
- Блокеры для stage-01: **нет**. Обе новые находки — документарные; код,
  тесты и сборка проверены независимо.
- Оговорка: CI-run'ы `39746024266` и `39755053239` независимо не проверены
  (приватный репозиторий, `gh` не установлен). Критерий сборки подтверждён
  локальным прогоном, поэтому это не блокер.

### Статус находок R00

| ID | Итог | Независимое доказательство (2026-10-22) |
|----|------|------------------------------------------|
| R00-001 | fixed | `64ab3a6`/`a68b224`/`73350d5` в `origin/master`; локально `analyze` 0 issues, `test` 24/24, `build windows --debug` success. CI — attestation. |
| R00-002 | fixed | `pubspec.lock:797-801`: `sqlite3` — `transitive`, `sqlite3_flutter_libs` отсутствует; `pub get --enforce-lockfile` → `Got dependencies!`, lock не изменён. |
| R00-003 | fixed | `assets/tray_icon.ico`: 2 изображения 16×16/32×32, 32 bpp; `desktop_services.dart:66-68` выбирает `.ico` на Windows; ассет есть в `build\...\data\flutter_assets\assets\`. |
| R00-004 | fixed | `docs/stages/stage-00.md:116-117` совпадает с `app_database.dart:57-69` и ADR-012. |
| R00-005 | fixed | `lib/core/crypto/crypto_service.dart`, `lib/core/sync/sync_service.dart`; контракты в `stage-00.md:104-105`. |
| R00-006 | fixed | `test/db_migration_test.dart:70-77` (PRAGMA=1), `:79-116` (v1→v2 без миграции → `UnsupportedError`); проходят. |
| R00-007 | fixed | Flutter 3.47.7 из `C:\src\flutter`; `C:\src\flutter\bin` есть в пользовательском PATH; analyze/test/build воспроизведены. |
| R00-008 | fixed | Контроллер в `lib/features/settings/application/`; старый путь удалён; ADR-001 обновлён. |
| R00-009 | fixed | `settings_controller.dart:78-151` — `try/catch`, откат состояния; failure-путь покрыт тестами. |
| R00-010 | accepted | ADR-010: стартовый заголовок окна до локализации. |
| R00-011 | accepted | ADR-006: обоснование пина `tray_manager 0.5.0`. |
| R00-012 | accepted | `PROMPT.md:2-5`: примечание об отсутствующих разделах 1–2. |
| R00-013 | fixed | `docs/decisions.md:40` указывает `lib/features/settings/application/settings_controller.dart`. |
| R00-014 | fixed | `setThemeMode`/`setLocale` → `bool`; `SnackBar` с `lcm.errorUnexpected` (`settings_screen.dart:72-78,102-111`); 3 теста в `test/settings_controller_test.dart`. |

### Новые находки

#### [MINOR] R00-015: Вердикт повторного ревью в журнале оформлен от имени agent-2, но добавлен разработчиком
- **Категория:** F (документация/процесс)
- **Где:** `docs/reviews/stage-00-review.md:233-249` (заголовок «Ревьюер: agent-2»);
  производные утверждения — `docs/stages/stage-00.md:6,193`,
  `docs/context.md:35-37,58-59`, `docs/INDEX.md:29-30`,
  `docs/tech-debt.md:176-179`.
- **Что не так:** блок «Повторное ревью (2026-10-22)» и вердикт PASS WITH
  COMMENTS приписаны agent-2, но `git blame -L 233,249` показывает, что
  строки этого блока добавлены коммитами `a68b224`/`73350d5` (работа agent-1),
  а не независимым ревьюером. В тексте agent-2 говорит о себе в третьем лице
  («agent-2 независимо не проверял…»), что подтверждает авторство agent-1.
  На этом блоке основаны PASS-формулировки в четырёх документах. Содержательные
  выводы блока этой проверкой подтверждены, поэтому находка MINOR, а не MAJOR;
  но как процессный паттерн (разработчик выставляет вердикт за ревьюера) она
  опасна: при повторении приёмка снова станет «на словах».
- **Как воспроизвести:**
  ```powershell
  git blame -L 233,249 -- docs/reviews/stage-00-review.md   # → a68b224 / 73350d5
  git show --stat a68b224                                   # коммит разработчика
  git log --format='%h %s' -5
  ```
- **Ожидаемое по ТЗ:** REVIEWER_PROMPT.md:4-8, 74-76 — ревью проводит agent-2,
  разработчик не выставляет вердикт; журнал отражает фактическое авторство.
- **Фактическое:** независимое ревью №2 фактически проведено только сейчас
  (этот раздел); предыдущий PASS-блок — самопроверка agent-1.
- **Предлагаемое исправление:** переатрибутировать блок 233-249 как
  «self-check agent-1» (либо удалить его после фиксации этого раздела как
  независимого ревью); в `stage-00.md`/`context.md`/`INDEX.md`/`tech-debt.md`
  сослаться на «Повторное ревью №2». Вердикт менять не нужно — он подтверждён.
- **Связанные ADR:** —
- **Статус:** open (документарная правка; не блокер stage-01)

#### [MINOR] R00-016: Отчёт утверждает подтверждённый запуск приложения, артефакта запуска нет
- **Категория:** F (документация), G (сборка/запуск)
- **Где:** `docs/stages/stage-00.md:15` — «сборка и запуск подтверждены
  (`build\windows\x64\runner\Debug\second_brain.exe`)»; там же `:16,19-20` —
  GUI-проверка трея/хоткея «вручную».
- **Что не так:** наличие `second_brain.exe` подтверждает **сборку**, но не
  запуск GUI. Лога `flutter run`/скриншота/записи ручного прогона в `docs` нет;
  сам отчёт ниже признаёт, что GUI-проверка не выполнялась. Критерий 1 включает
  «приложение запускается на Windows».
- **Как воспроизвести:**
  ```powershell
  Test-Path build\windows\x64\runner\Debug\second_brain.exe   # True (сборка)
  Select-String docs/stages/stage-00.md -Pattern 'запуск'
  # артефакта запуска (лог/скриншот) в docs нет
  ```
- **Ожидаемое по ТЗ:** STAGE_ONE.md:51,58; REVIEWER_PROMPT.md:54-57 — критерий
  подтверждается артефактом, а не формулировкой.
- **Фактическое:** подтверждена сборка; запуск GUI не зафиксирован.
- **Предлагаемое исправление:** либо приложить лог/скриншот ручного запуска,
  либо заменить на «сборка подтверждена; запуск GUI — ручная проверка
  (не зафиксирован)». После ручного прогона отметить трей и Ctrl+Alt+B.
- **Связанные ADR:** ADR-009
- **Статус:** open (документарная правка; не блокер stage-01)

### Чек-лист A–H (независимая проверка)

- **A. Соответствие ТЗ:** все 7 критериев имеют артефакт; analyze/test/build
  воспроизведены локально; навигация/темы/язык/БД покрыты тестами. GUI-пункты
  (трей, хоткей, запуск) — код готов, ручной прогон не зафиксирован (R00-016).
  Scope creep нет: `.ico`, `CryptoService`/`SyncService`, `build-windows` прямо
  требуются ТЗ/ADR.
- **B. Архитектура:** `lib/app` — композиция; `SettingsController` — в
  `features/settings/application`; слои и DI Riverpod не нарушены; публичные
  контракты сохранены.
- **C. Данные/миграции:** схема v1 (`key/value/updated_at`, PK `key`);
  `onCreate → createAll`, `onUpgrade` без `createAll` + явный `UnsupportedError`,
  `beforeOpen → PRAGMA foreign_keys = ON` (`app_database.dart:52-74`); PRAGMA и
  файловый переход v1→v2 покрыты тестами. На stage-01 ветку v1→v2 добавить до
  повышения `schemaVersion`.
- **D. Безопасность:** секретов в репозитории/коде/логах нет (`git grep` по
  типовым паттернам — пусто); `SecretStore` через `flutter_secure_storage`;
  LLM-вызовов на stage-00 нет.
- **E. Качество/тесты:** `analyze --fatal-infos` → 0 issues; `flutter test` →
  24/24; TODO/FIXME в `lib/` нет; ARB EN/RU — по 31 ключу, наборы совпадают;
  хардкод только принятый стартовый заголовок окна (R00-010).
- **F. Документация:** INDEX/context/decisions/tech-debt/stage-00 в основном
  соответствуют коду; R00-015 (атрибуция) и R00-016 («запуск») закрыты
  2026-10-22.
- **G. Сборка/запуск:** lock консистентен (`--enforce-lockfile` проходит);
  `build windows --debug` → success; GUI-поведение трея/хоткея не проверялось;
  CI — attestation (независимо не проверен).
- **H. Регрессии:** навигация, темы, сброс языка, локализация, crash-hooks,
  desktop-guard, миграции — без регрессий; 24/24 зелёные.

### Соответствие критериям приёмки (повторно)

- [x] **1. Приложение запускается на Windows, показывает навигацию.** Сборка
  success; widget-тесты поднимают приложение и навигацию; GUI-запуск не
  зафиксирован (R00-016).
- [x] **2. Переключаются язык и тема.** `SettingsController` + `SettingsScreen`,
  unit/widget-тесты.
- [x] **3. Иконка в трее и горячая клавиша (код).** `.ico` 16/32, Windows-путь
  `LoadImage(IMAGE_ICON)`, Ctrl+Alt+B; GUI-проверка — вручную.
- [x] **4. БД создаётся, миграции применяются.** Схема v1, `onCreate`,
  `PRAGMA`, тест v1→v2 `UnsupportedError`.
- [x] **5. Analyze чистый, тесты зелёные, сборка Windows проходит.** Локально
  воспроизведено: 0 issues, 24/24, build success.
- [x] **6. `/docs` заполнены.** Полный набор; открыты две документарные находки
  (R00-015, R00-016).
- [x] **7. Секретов в репозитории нет.** `git grep` и `git ls-files` чисты;
  `.env` исключён.

### Расхождения документации с кодом (актуальные)

1. **R00-015:** PASS-блок в журнале ревью атрибутирован agent-2, но добавлен
   разработчиком; производные документы ссылаются на него как на независимое ревью.
2. **R00-016:** `stage-00.md:15` заявляет подтверждённый запуск, есть только
   артефакт сборки.
3. **`docs/stages/stage-00.md:32`** — описание CI перечисляет только
   `pub get + analyze + test`, хотя в workflow есть job `build-windows`
   (nit, отдельной находкой не завожу).
4. **ADR-009** описывает `build-windows` как pub get + build, фактически там
   ещё `flutter test` (`.github/workflows/ci.yml:54-55`) — уточнение.

### Рекомендации

1. Закрыть R00-015/R00-016 документарным коммитом: переатрибутировать
   self-check и либо приложить артефакт запуска, либо честно пометить запуск
   как непроверенный.
2. На stage-01: ветку `if (from < 2)` добавить **до** повышения
   `schemaVersion`; тест — на файловой БД v1 с проверкой данных после
   успешной миграции; тест на `UnsupportedError` сохранить.
3. После ручного прогона `flutter run -d windows` приложить лог/скриншот трея
   и Ctrl+Alt+B в `stage-00.md`.
4. Сохранять `pub get --enforce-lockfile` в CI и коммитить lock при изменениях
   зависимостей.
5. Правило процесса: журнал `stage-XX-review.md` и вердикт заполняет только
   agent-2; self-check разработчика — отдельный раздел с явной атрибуцией.

### Приложение: фактические прогоны (2026-10-22, локально)

```text
Flutter 3.47.7 • Dart 3.13.5
flutter pub get --enforce-lockfile  → Got dependencies! (lock не изменён)
flutter analyze --fatal-infos       → No issues found! (ran in 18.8s)
flutter test --reporter expanded    → +24: All tests passed!
flutter build windows --debug       → √ Built build\windows\x64\runner\Debug\second_brain.exe
git ls-remote origin refs/heads/master → 73350d5… (push подтверждён)
```

Дополнительно: `.ico` — 2 изображения 16×16/32×32, 32 bpp; ARB EN/RU — по
31 ключу, расхождений нет; `sqlite3_flutter_libs` в `pubspec.lock` отсутствует;
`assets/tray_icon.ico` присутствует в `build\...\data\flutter_assets\assets\`;
секретов не найдено.
