# Реестр технического долга

Файл ведётся по правилам `PROMPT.md`: каждая позиция имеет ID, критичность,
ссылку на код/ТЗ и решение. Закрытые позиции не удаляются — меняется статус и
добавляется ссылка на ADR/коммит, чтобы новый агент видел историю.

Легенда критичности: **CRITICAL** — ломает сборку/данные/безопасность;
**MAJOR** — функциональная ошибка или грубое нарушение ТЗ; **MINOR** — неточность,
неполное покрытие; **NIT** — стиль/мелочи.

Легенда статуса: `open` / `fixed` / `accepted` (осознанно отложено) / `wontfix`.

## Сводка

| Статус | Кол-во |
|--------|--------|
| open | 0 |
| fixed | 36 |
| accepted | 15 |
| pending | 0 |

> **Ревью stage-02 (2026-10-23):** открыты 2 MAJOR и 6 MINOR
> (R02-001…R02-008). Все 8 находок исправлены agent-1 (код-коммит `8956179`);
> источник: [reviews/stage-02-review.md](reviews/stage-02-review.md),
> результаты: [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md).
>
> **Повторное ревью №2 (2026-10-24):** R02-001…R02-008 подтверждены как
> закрытые; открыты R02-009 (MAJOR, хоткей), R02-010/R02-011 (MINOR),
> R02-012/R02-013 (NIT). Вердикт — **FAIL**; stage-03 блокировался до закрытия
> R02-009 или его официального принятия как TD-27.
>
> **Исправления agent-1 (2026-10-24, коммиты `a50d972` и `92a9642`):**
> R02-009…R02-013 закрыты. Для R02-009 выбран вариант A — вендорный патч
> `third_party/hotkey_manager_windows` (ADR-017). Отчёт разработчика:
> [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
>
> **Повторное ревью №3 (2026-10-24):** **PASS WITH COMMENTS**; R02-009…R02-013
> подтверждены, MAJOR нет. Два не блокирующих комментария не заведены как TD:
> R02-014 (MINOR — сводка экрана финансов всё ещё смешивает валюты) и R02-015
> (NIT — повторный error-лог при сбое отметки напоминания). Если они не будут
> исправлены в ближайшем коммите, их следует принять как TD до релиза.

Проверка после исправлений R02-009…R02-013 (2026-10-24, Flutter 3.47.7):
`flutter pub get --enforce-lockfile` → OK; `flutter analyze --fatal-infos` →
0 issues; `flutter test` → **77/77**; `flutter build windows --debug` →
**success**; `gen-l10n` без дрейфа (128 message-ключей в RU/EN + `@@locale`). CI runs
`39919792561` (`82b04a2`), `39920666645` (`296970b`), `39931858624`
(`e8c6005`, включает `8956179`), `40091767297` (`f9511c0`) — **success**;
run `40095276919` (`92a9642`) — см.
[reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md). CI
stage-01: run `39763804171` — success.

---

## Закрыто в проходе «tech-debt-01» (2026-10-22)

### TD-01 — Сброс языка на «системный» не применялся
- **Критичность:** MAJOR
- **Область:** `lib/features/settings/application/settings_controller.dart`
- **Проблема:** `SettingsState.copyWith({Locale? locale})` использовал
  `locale ?? this.locale`, поэтому `setLocale(null)` не сбрасывал язык: UI
  оставался на старом языке до перезапуска (в БД при этом писалось `system`).
- **Решение:** sentinel-параметр `Object? locale = _unset` + значение по
  умолчанию `!= _unset`; добавлены `==`/`hashCode` для предсказуемых rebuild.
- **Тесты:** `copyWith` (unit) + widget-тест «ru → system сбрасывает локаль».
- **Статус:** fixed

### TD-02 — Хардкод UI-строк в трее и заголовке окна
- **Критичность:** MAJOR (нарушение ADR-008: весь UI-текст только из ARB)
- **Область:** `lib/app/desktop_services.dart`, `lib/app/app.dart`
- **Проблема:** меню трея (`Show window` / `Hide window` / `Quit`), тултип и
  заголовок окна были английскими константами, хотя ключи `trayMenuShow`,
  `trayMenuHide`, `trayMenuQuit`, `appTitle` уже были в ARB и не использовались.
- **Решение:** `DesktopServices.init()` теперь поднимает только окно и хоткей;
  трей настраивается методом `setTrayLabels(...)` из `SecondBrainApp`, когда
  `AppLocalizations` доступны. Метод идемпотентен и вызывается повторно при
  смене языка (`didChangeDependencies`), тултип/меню/заголовок окна
  перерисовываются без перезапуска.
- **Статус:** fixed

### TD-03 — Ошибка desktop-инициализации роняла запуск приложения
- **Критичность:** MAJOR
- **Область:** `lib/app/desktop_services.dart`, `lib/main.dart`
- **Проблема:** `_initHotkey()` не был обёрнут в try/catch: занятая комбинация
  (другое приложение) выбрасывала исключение из `main()` — приложение не
  стартовало. `DesktopServices.init()` в `main()` тоже был без защиты.
- **Решение:** хоткей и весь desktop-блок изолированы, ошибки логируются,
  приложение продолжает работу без трея/хоткея (требование «не критично»).
- **Статус:** fixed

### TD-04 — Неверная подсветка нижней навигации на узких экранах
- **Критичность:** MAJOR
- **Область:** `lib/app/router.dart`
- **Проблема:** для веток вне `kMobileNavBranches` (settings, ideas, finance,
  learning, integrations, search) `selectedIndex = -1 → 0`, то есть
  подсвечивался «Дашборд». Пользователь видел неверный активный раздел.
- **Решение:** если текущая ветка не входит в нижнюю панель, активной
  считается «Ещё» (последняя ветка), откуда эти разделы и открываются.
- **Тесты:** widget-тест «узкое окно: скрытая ветка подсвечивает Ещё».
- **Статус:** fixed

### TD-05 — Устаревшие дубликаты документации в корне
- **Критичность:** MAJOR (дезинформация нового агента)
- **Область:** корень репозитория
- **Проблема:** `INDEX.md`, `context.md`, `debug-log.md`, `stage-XX.md`,
  `stage-XX-review.md`, `decisions.template.md` в корне были шаблонами/копиями
  с «Текущий этап: stage-XX» и ссылками на несуществующие пути. Актуальные
  версии лежат только в `docs/`.
- **Решение:** дубликаты удалены; единственная точка входа — `docs/INDEX.md`
  (ссылки в README и PROMPT.md уже ведут в `docs/`).
- **Статус:** fixed

### TD-06 — Критерий «сборка Windows» не автоматизирован
- **Критичность:** MAJOR (незакрытый критерий приёмки stage-00)
- **Область:** `.github/workflows/ci.yml`
- **Проблема:** CI гонял только analyze + test на Ubuntu; `flutter build
  windows` не выполнялся нигде, поэтому критерий этапа 0 оставался
  неподтверждённым (ADR-007).
- **Решение:** добавлен job `build-windows` на `windows-latest`
  (`flutter build windows --debug`), плюс `concurrency` для отмены устаревших
  прогонов. Локальная установка Visual Studio больше не обязательна для
  подтверждения сборки.
- **Статус:** fixed

### TD-07 — EOL-пакет `sqlite3_flutter_libs`
- **Критичность:** MINOR (пакет-пустышка, но вводит в заблуждение)
- **Область:** `pubspec.yaml`
- **Проблема:** `sqlite3_flutter_libs 0.6.0+eol` по документации pub.dev больше
  ничего не делает: `drift 2.35` уже зависит от `sqlite3 ^3.4.0`, а SQLite
  подключается через hooks. Пакет только создаёт иллюзию нативной сборки.
- **Решение:** зависимость удалена; версия `sqlite3` приходит транзитивно от
  drift. Обновление `pubspec.lock` — через `flutter pub get`.
- **Статус:** fixed (см. ADR-011)

### TD-08 — `createAll()` в `onUpgrade` маскирует отсутствие миграций
- **Критичность:** MINOR сейчас / MAJOR на stage-01
- **Область:** `lib/data/db/app_database.dart`
- **Проблема:** при `from < to` вызывался `createAll()`, который создаёт только
  недостающие таблицы и молча пропускает `ALTER TABLE`/перенос данных. На
  stage-01 (v1 → v2) это могло привести к неверной схеме вместо явной ошибки.
- **Решение:** `onUpgrade` больше не вызывает `createAll()`; для
  непрекрытого перехода бросается `UnsupportedError` с просьбой добавить
  миграцию. Новая версия схемы без миграции теперь падает в тестах сразу.
- **Статус:** fixed (см. ADR-012)

### TD-09 — Crash-reporter не перехватывал Flutter/async ошибки
- **Критичность:** MINOR
- **Область:** `lib/core/crash/app_crash_reporter.dart`
- **Проблема:** `AppCrashReporter.run()` ловил только ошибки внутри `main()`,
  но не `FlutterError.onError` и не `PlatformDispatcher.onError`, хотя
  doc-комментарий обещал «каждая ошибка попадает в лог».
- **Решение:** в `init()` устанавливаются оба хука; ошибки пишутся через
  `AppLogger.e`, исходный `FlutterError.onError` сохраняется и вызывается.
- **Статус:** fixed

### TD-10 — Сырой текст ошибки в UI настроек
- **Критичность:** MINOR (утечка внутренних деталей + нелокализованный текст)
- **Область:** `lib/features/settings/presentation/settings_screen.dart`
- **Проблема:** при ошибке загрузки настроек выводилось
  `'${lcm.errorUnexpected}: $e'` — исключение с путями/деталями БД попадало в
  интерфейс; кнопки повтора не было.
- **Решение:** пользователю показывается только локализованное сообщение,
  подробности — в лог; добавлена кнопка «Повторить»
  (`ref.invalidate(settingsControllerProvider)`), ключ `retryAction` в ARB.
- **Статус:** fixed

### TD-11 — `dart:io` в `main.dart` ломал web-сборку
- **Критичность:** MINOR (web — заявленная будущая платформа)
- **Область:** `lib/main.dart`
- **Проблема:** `Platform.isWindows` из `dart:io` делает точку входа
  несовместимой с web (`dart:io` недоступен).
- **Решение:** заменено на `!kIsWeb && defaultTargetPlatform ==
  TargetPlatform.windows`; импорт `dart:io` удалён.
- **Статус:** fixed

### TD-12 — Мелкие дефекты API/вёрстки
- **Критичность:** NIT
- **Область:** несколько файлов
- **Проблема и решение:**
  - `Result.valueOrDefault` бросал `StateError` (ловушка по имени) и не
    использовался — удалён.
  - `IntrinsicHeight` вокруг `NavigationRail` давал лишний layout-проход —
    удалён.
  - `moreTitle` не использовался (экран «Ещё» брал `navMore`) — AppBar
    переведён на `moreTitle`.
  - опечатка «первая веткао шелла» в названии теста — исправлена.
- **Статус:** fixed

### TD-13 — Не хватало тестов на исправленные сценарии
- **Критичность:** MINOR
- **Область:** `test/`
- **Проблема:** не были покрыты сброс локали и подсветка нижней навигации —
  именно поэтому TD-01 и TD-04 дожили до ревью.
- **Решение:** добавлены unit-тест `copyWith(locale: null)` и два
  widget-теста (сброс локали, скрытая ветка → «Ещё»).
- **Статус:** fixed

---

## Закрыто по ревью stage-00 (R00, 2026-10-22)

Ревьюер agent-2 открыл 12 находок (см.
[reviews/stage-00-review.md](reviews/stage-00-review.md)); повторное ревью
2026-10-22 дало PASS WITH COMMENTS и добавило R00-013/R00-014. Ниже — реакция
разработчика; все находки закрыты, кроме осознанно принятых R00-010…R00-012.

| ID | Критичность | Находка | Действие | Статус |
|----|-------------|---------|----------|--------|
| R00-001 | MAJOR | изменения не закоммичены, CI не прогнан | коммит `64ab3a6` + push; оба job'а зелёные | fixed |
| R00-002 | MAJOR | `pubspec.lock` не обновлён после TD-07 | `flutter pub get` обновил lock; CI использует `--enforce-lockfile` | fixed |
| R00-003 | MAJOR | трей грузит PNG через `LoadImage(IMAGE_ICON)` | добавлен `assets/tray_icon.ico` (16/32 px); Windows берёт ICO | fixed |
| R00-004 | MAJOR | `stage-00.md` противоречил ADR-012 | абзац про `createAll` удалён, тесты обновлены | fixed |
| R00-005 | MAJOR | нет заготовок `CryptoService`/`SyncService` | добавлены интерфейсы в `lib/core/crypto`, `lib/core/sync` | fixed |
| R00-006 | MINOR | тест миграций не проверял PRAGMA/onUpgrade | добавлены тесты PRAGMA=1 и `UnsupportedError` при v1→v2 | fixed |
| R00-007 | MINOR | окружение и проверки не воспроизводились | установлен Flutter 3.47.7; analyze 0 issues, tests 24/24 | fixed |
| R00-008 | MINOR | логика settings жила в `lib/app` | перенесена в `features/settings/application/` | fixed |
| R00-009 | MINOR | ошибка репозитория давала unhandled exception | `try/catch` + откат в `setThemeMode`/`setLocale` | fixed |
| R00-010 | NIT | стартовый заголовок окна — константа | осознанное исключение зафиксировано в ADR-010 | accepted |
| R00-011 | NIT | ADR-006 не объяснял пин 0.5.0 vs 0.5.3 | добавлено обоснование в ADR-006 | accepted |
| R00-012 | NIT | в `PROMPT.md` нет разделов 1–2 | добавлено примечание в начале файла | accepted |
| R00-013 | MINOR | ADR-001 ссылался на удалённый `lib/app/settings_controller.dart` | путь обновлён на `features/settings/application/` | fixed |
| R00-014 | MINOR | откат настроек не покрыт тестом и не виден пользователю | `setThemeMode`/`setLocale` → `bool`, SnackBar с `lcm.errorUnexpected`; 3 теста failure/success | fixed |
| R00-015 | MINOR | PASS-блок self-check приписан agent-2 | блок переименован в «Self-check agent-1», авторство и ссылки исправлены | fixed |
| R00-016 | MINOR | «запуск подтверждён» без артефакта | формулировка: сборка подтверждена, запуск GUI не зафиксирован (нужен ручной прогон) | fixed |

Локальные доказательства: `docs/context.md` (снимок), 24 теста, 0 issues.
Повторное ревью №2 (2026-10-22, agent-2): R00-001…R00-014 подтверждены;
R00-015/R00-016 (minor, документация) закрыты в `docs` — см.
[reviews/stage-00-review.md](reviews/stage-00-review.md).
CI-доказательство (R00-001): коммит `64ab3a6`, run
[39746024266](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266) —
`analyze-and-test` и `build-windows` завершились **success** (проверено через
GitHub API: job'ы
[analyze-and-test](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266/job/119714562468) и
[build-windows](https://github.com/HoudiwinG/second-brain/actions/runs/39746024266/job/119714562295)).
Финальный коммит с R00-013/R00-014 — `a68b224`, run
[39755053239](https://github.com/HoudiwinG/second-brain/actions/runs/39755053239)
— оба job'а **success**.

---

## Закрыто на stage-02 (2026-10-23)

### TD-15 — Хоткей Ctrl+Alt+B не настраивается
- **Критичность:** MINOR
- **Область:** `lib/app/quick_hotkey.dart`,
  `lib/features/settings/application/settings_controller.dart`,
  `lib/features/settings/presentation/settings_screen.dart`,
  `lib/features/settings/presentation/hotkey_recorder_dialog.dart`,
  `lib/app/desktop_services.dart`
- **Проблема:** глобальная комбинация была константой `Ctrl+Alt+B`; пользователь
  не мог её изменить, а при занятой комбинации не было управляемого отката.
- **Решение:** `QuickHotkey` хранится в `app_settings` как JSON
  (`hotkey.quick_capture`); в настройках появилась запись комбинации через
  `HotKeyRecorder`. `SettingsController.setQuickHotkey` регистрирует новую
  комбинацию, сохраняет её и откатывает состояние/прежнюю регистрацию при
  ошибке. На не-Windows платформах applier — no-op.
  **Обновление (2026-10-24, R02-009/TD-27):** после вендорного патча
  `RegisterHotKey` возвращает ошибку `hotkey_busy`, поэтому откат при занятой
  комбинации достижим и покрыт ручным Windows-сценарием (ADR-017).
- **Тесты:** `test/quick_hotkey_test.dart` (сериализация, валидация, equality);
  `test/settings_controller_test.dart` (успех и занятая комбинация);
  `test/desktop_services_test.dart` (откат через тестируемый `applyHotkeyBinding`,
  контракт `hotkey_busy` в патче, path-источник в `pubspec.yaml`).
- **Статус:** fixed (ADR-016, ADR-017)

---

## Закрыто по ревью stage-02 (R02, 2026-10-23)

Ревьюер agent-2 открыл 2 MAJOR и 6 MINOR (см.
[reviews/stage-02-review.md](reviews/stage-02-review.md)). Agent-1 исправил все
8 находок код-коммитом `8956179`; подробные доказательства —
[reviews/stage-02-review-results.md](reviews/stage-02-review-results.md).
Повторное ревью №2 (2026-10-24) подтвердило закрытие всех восьми находок
(код, тесты, независимый Windows-smoke).

| ID | Критичность | Находка | Действие | Статус |
|----|-------------|---------|----------|--------|
| R02-001 | MAJOR | относительный путь к иконке трея; `_trayReady=true` без проверки загрузки | абсолютный путь от `Platform.resolvedExecutable`, `File.existsSync()`, `_trayReady` только после успешной установки; smoke из каталога `.exe` | fixed |
| R02-002 | MAJOR | ошибка toast проглатывалась, `reminder_sent_at` ставился | `ReminderNotifier.show → Future<bool>`; отметка только при `true`, иначе повтор на следующем тике; failing-тесты | fixed |
| R02-003 | MINOR | startup-apply хоткея не ожидался, `false` игнорировался, early return мешал retry | `await` + fallback default + сохранение фактической комбинации; early return удалён; тест | fixed |
| R02-004 | MINOR | guard `to > 3` после DDL; downgrade принимался | guard `from > to || from > 3 || to > 3` до DDL; тесты `v2 → v4`, `v4 → v3` | fixed |
| R02-005 | MINOR | `to` включителен, операция 1-го числа попадала в прошлый месяц | контракт `[from, to)`, `isSmallerThanValue`; тест границы | fixed |
| R02-006 | MINOR | ошибка quick capture оставляла `_saving=true` без сообщения | `try/catch/finally`, локализованная ошибка, сброс `_saving`; widget-тест | fixed |
| R02-007 | MINOR | не было regression-тестов на найденные сценарии | добавлены failing notifier/startup/backup/границы/миграции/quick capture/трей; 69/69 | fixed |
| R02-008 | MINOR | `dayEnd = dayStart + 24h` ломался на DST | календарные границы в `dashboard_period.dart`; тест | fixed |

Локальные доказательства: `flutter analyze --fatal-infos` — 0 issues;
`flutter test` — 69/69; `flutter build windows --debug` — success; smoke
close-to-tray из каталога `.exe` — процесс остался жив после WM_CLOSE.

## Закрыто по повторному ревью №2 stage-02 (2026-10-24)

| ID | Критичность | Находка | Действие | Статус |
|----|-------------|---------|----------|--------|
| R02-009 | MAJOR | занятая глобальная комбинация не обнаруживается на Windows: плагин игнорирует результат `RegisterHotKey`, откат недостижим | вендорный патч `third_party/hotkey_manager_windows` + `dependency_overrides`; `PlatformException(hotkey_busy)` → `applyHotkeyBinding` → `false` → откат и `hotkeyBusyError` (ADR-017) | fixed |
| R02-010 | MINOR | повторные неудачи toast без backoff: попытка/warning каждые 30 с; при сбое отметки — повтор toast | backoff 30 с → 1 мин → 5 мин → 15 мин на задачу; при `show()==true` и сбое `markReminderSent` повторяется только отметка, toast не дублируется; failing-notifier + fake clock тесты | fixed |
| R02-011 | MINOR | сводка финансов на дашборде смешивает валюты (`summary` без `currency`) | `FinanceDraft.defaultCurrency` (`RUB`) как единый источник; `summary(currency:)`; валюта в подписи каждой ячейки (`financeAmountWithCurrency`); тест с двумя валютами | fixed |
| R02-012 | NIT | `RefreshIndicator` завершается до загрузки данных | `_reload()` возвращает `Future<void>`, `onRefresh` ждёт её; `await` в retry/onPressed; widget-тест | fixed |
| R02-013 | NIT | устаревший лог «этап 0 — каркас» в `main.dart` | лог заменён на «Second Brain: приложение запущено» | fixed |

Доказательства: [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md);
локально analyze 0, test 77/77, Windows debug build success; ручной
Windows-сценарий занятой комбинации — там же.

### TD-27 — Обнаружение занятой глобальной комбинации на Windows
- **Критичность:** MAJOR, **статус:** fixed (ADR-017)
- **Область:** `third_party/hotkey_manager_windows/`,
  `pubspec.yaml` (`dependency_overrides`), `lib/app/desktop_services.dart`,
  `lib/features/settings/application/settings_controller.dart`
- **Проблема:** нативный плагин вызывал `::RegisterHotKey(...)` и игнорировал
  возвращённый `BOOL`, после чего всегда отвечал `Success(true)`
  (`hotkey_manager_windows_plugin.cpp:104-108` upstream). Dart-обёртка
  возвращала `Future<void>`. Поэтому `setQuickCaptureHotkey` не мог вернуть
  `false`: откат на прежнюю комбинацию и SnackBar `hotkeyBusyError` в
  production были недостижимы. Если комбинацию занимало другое приложение,
  она молча отображалась как активная, но не работала. Находка ревью —
  R02-009.
- **Решение (вариант A):** `hotkey_manager_windows 0.2.0` скопирован в
  `third_party/hotkey_manager_windows/` и подключён через
  `dependency_overrides` в `pubspec.yaml`. В `Register` проверяется результат
  `::RegisterHotKey`; при `FALSE` возвращается
  `result->Error("hotkey_busy", ...)` с `GetLastError()` и выполняется `return`
  **до** вставки в `hotkey_id_map_`, чтобы не оставлять осиротевший id.
  Изменения upstream минимальны (0.2.0), описание — в
  `third_party/hotkey_manager_windows/PATCH.md`.
- **Dart-сторона:** регистрация вынесена в тестируемый
  `DesktopServices.applyHotkeyBinding(binding, register:, unregisterAll:)`
  с typedef `HotkeyRegistrar`; `PlatformException` из плагина перехватывается,
  возвращается `false`, прежняя комбинация регистрируется повторно.
  `SettingsController` уже откатывает state и сохранение, показывает
  локализованный `hotkeyBusyError`.
- **Тесты:** `test/desktop_services_test.dart` — откат при ошибке регистрации,
  наличие контракта `hotkey_busy` в вендорном `.cpp`, path-источник в
  `pubspec.yaml`; существующие `settings_controller_test.dart` проверяют
  откат state/сохранения.
- **Ручная проверка:** `tool/occupy_hotkey.ps1` занимает `Ctrl+Alt+B`;
  при запуске приложение получило `PlatformException(hotkey_busy, …, 1409)`,
  продолжило работу и залогировало неудачное применение. После освобождения
  комбинации регистрация прошла успешно. UI-смена комбинации в настройках
  проверена пользователем 2026-10-24: SnackBar и откат работают.
- **Связанные ADR:** ADR-016, ADR-017; находка R02-009.

---

## Принято осознанно (не закрывается в этом проходе)

### TD-14 — `tray_manager` зафиксирован на 0.5.0
- **Критичность:** MINOR, **статус:** accepted
- **Причина:** 0.6+ требует C-тулчейн (nativeapi) для тестов; локально Visual
  Studio нет. Stage-02 подтвердил, что 0.5.0 достаточно для меню трея,
  close-to-tray и локализованных подписей.
- **Триггер пересмотра:** установка VS или появление требований, которых нет в
  0.5.0.
- **2026-10-24:** триггер сработал — VS Build Tools 2022 установлены на текущем
  ПК, `sdkmanager`/MSVC доступны, поэтому миграция на `tray_manager` 0.6+
  технически разблокирована. Не выполняется в этом проходе: требует проверки
  API 0.8 и smoke трея; пин 0.5.0 остаётся рабочим.

### TD-16 — `ApiClient.request` — заглушка без HTTP
- **Критичность:** MINOR, **статус:** accepted
- **Причина:** по плану транспорт подключается на stage-03/06 вместе с
  LLM/интеграциями; контракт (таймауты, retry, логирование) уже зафиксирован.
- **Триггер:** stage-03 (LLM-слой).

### TD-17 — `.env.example` не используется кодом
- **Критичность:** NIT, **статус:** accepted
- **Причина:** секреты по ADR-003 живут только в secure storage; файл оставлен
  как шаблон для локальных/CI-переменных. Ревизия — на stage-03/06.
- **Триггер:** подключение LLM/OAuth.

### TD-18 — Нет golden-тестов UI
- **Критичность:** MINOR, **статус:** accepted
- **Причина:** на stage-02 добавлены widget-тесты дашборда и быстрого ввода, но
  golden-эталонов и визуальной регрессии по-прежнему нет.
- **Триггер:** отдельный UX-проход после stage-03 или настройка стабильного
  рендеринга в CI.

### TD-19 — `AppLocalizations.of(context)!` в точках вызова
- **Критичность:** NIT, **статус:** accepted
- **Причина:** следствие codegen Flutter (nullable `of`), зафиксировано в
  ADR-008; замена на extension — рефакторинг без функционального эффекта.
- **Триггер:** при следующем массовом добавлении экранов.

### TD-20 — В CI нет проверки `dart format`
- **Критичность:** NIT, **статус:** accepted
- **Причина:** текущий `dart format` переформатирует legacy-файлы (switch-
  выражения и переносы), создавая большой несвязанный diff; включение в CI
  без отдельного formatting-pass даст шум.
- **Триггер:** отдельный formatting-pass с фиксацией версии formatter и
  исключений для generated-файлов.

---

## Принято осознанно на stage-01 (2026-10-22)

### TD-21 — Финансовая сумма хранится как `REAL`
- **Критичность:** MAJOR, **статус:** accepted
- **Область:** `finance_transactions.amount`, `FinanceRepository.summary`
- **Причина:** для MVP и импорта CSV выбрано `double`; на больших суммах и
  повторном суммировании возможны ошибки округления. Перевод на целые
  минорные единицы потребует новой миграции (`v3 → v4`), изменения CSV/JSON и
  UI.
- **Триггер пересмотра:** бюджеты/аналитика (stage-04+) или появление
  многовалютных отчётов.

### TD-22 — Нет `User`, вложений и learning/chat-таблиц
- **Критичность:** MINOR, **статус:** accepted
- **Область:** схема данных
- **Причина:** stage-01 закрывает локальное ядро; `User` нужен для
  мультиаккаунта, вложения — для файлового хранилища, learning/chat — для
  последующих этапов. Таблицы-заготовки без репозиториев и UI создавали бы
  ложное ощущение готовности.
- **Триггер:** stage-03 (LLM/чат) и последующие этапы по `PROMPT.md`
  (пользователи/вложения).

### TD-23 — Экспорт/импорт по вводу пути вместо file-picker
- **Критичность:** MINOR, **статус:** accepted
- **Область:** `settings_screen.dart`, `BackupService`
- **Причина:** плагин выбора файлов добавляет платформенную зависимость и
  усложняет тесты; путь по умолчанию и ручной ввод достаточны для stage-01/02.
- **Триггер:** отдельная UX-полировка (stage-03+).

### TD-24 — Нет UI восстановления и окончательного удаления
- **Критичность:** MINOR, **статус:** accepted
- **Область:** soft-delete
- **Причина:** данные уже помечаются `deleted_at`, но экраны не показывают
  корзину и не умеют restore/purge; это UX-функция следующего UX-прохода.
- **Триггер:** stage-03+.

---

## Принято осознанно на stage-02 (2026-10-23)

### TD-25 — Напоминания живут только при запущенном приложении
- **Критичность:** MINOR, **статус:** accepted
- **Область:** `ReminderScheduler`, `LocalReminderNotifier`
- **Причина:** планировщик — `Timer.periodic` внутри процесса приложения. Если
  пользователь полностью вышел через трей, ОС не показывает напоминания;
  автозапуск, Task Scheduler и фоновый сервис не входят в stage-02.
- **Триггер:** этап, где появятся автозапуск/фоновая служба, или требование
  напоминаний после полного выхода.

### TD-26 — Уведомление не открывает задачу и не имеет действий
- **Критичность:** MINOR, **статус:** accepted
- **Область:** `LocalReminderNotifier`
- **Причина:** клик по toast показывает и фокусирует окно, но не переходит к
  карточке задачи; кнопок «Отложить/Выполнено» нет. Для stage-02 достаточно
  самого факта напоминания.
- **Триггер:** UX-доработка напоминаний (deep link + actions).
