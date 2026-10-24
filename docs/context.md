# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-02 (UX-каркас) завершён — **PASS WITH COMMENTS**
  (ревью №3); следующий — stage-03 (LLM-слой)
- **Статус:** R02-001…R02-013 закрыты; открытых MAJOR/CRITICAL нет.
  Ревью №3: **PASS WITH COMMENTS**, minor 1 (R02-014 — сводка экрана финансов
  всё ещё смешивает валюты), nit 1 (R02-015 — error-лог при повторных сбоях
  отметки напоминания); оба комментария не блокируют stage-03. Для R02-009
  выбран вариант A — вендорный патч `hotkey_manager_windows` +
  `dependency_overrides` (ADR-017); busy-сценарий при старте воспроизведён,
  GUI-клик со SnackBar остаётся ручным шагом.
  Локально: analyze 0, test **77/77**, Windows debug build success; CI runs
  [39919792561](https://github.com/HoudiwinG/second-brain/actions/runs/39919792561),
  [39920666645](https://github.com/HoudiwinG/second-brain/actions/runs/39920666645),
  [39931858624](https://github.com/HoudiwinG/second-brain/actions/runs/39931858624),
  [40091767297](https://github.com/HoudiwinG/second-brain/actions/runs/40091767297),
  [40095276919](https://github.com/HoudiwinG/second-brain/actions/runs/40095276919),
  [40095857001](https://github.com/HoudiwinG/second-brain/actions/runs/40095857001),
  [40097546532](https://github.com/HoudiwinG/second-brain/actions/runs/40097546532)
  — **success** (проверено через `gh`).
- **Последний закрытый этап:** stage-01 (ядро данных) — **done**, CI run
  [39763804171](https://github.com/HoudiwinG/second-brain/actions/runs/39763804171)
  — success; ревью stage-01 не проводилось.
- **Текущий отчёт:** [stages/stage-02.md](stages/stage-02.md)
- **Текущее ревью:** [reviews/stage-02-review.md](reviews/stage-02-review.md) —
  актуальный вердикт **PASS WITH COMMENTS** (ревью №3, 2026-10-24); исторические
  вердикты **FAIL** (ревью и повторное №2). Результаты исправлений
  R02-001…R02-008 —
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md),
  R02-009…R02-013 —
  [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0; **MINOR:** 1 (R02-014, экран финансов);
  **NIT:** 1 (R02-015, лог retry). TD-21 — отдельное принятое ограничение
  `REAL` для финансов.
- **Сборка:** `flutter analyze --fatal-infos` — 0 issues;
  `flutter test` — **77/77**; `flutter build windows --debug` — **success**
  (2026-10-24, локально, `build\windows\x64\runner\Debug\second_brain.exe`)
- **Flutter SDK:** 3.47.7 stable, `C:\src\flutter` (Dart 3.13.5)
- **Windows-тулчейн:** Visual Studio Build Tools 2022 17.14 (MSVC v143 +
  Windows SDK + ATL/ATLMFC), установлен 2026-10-24; `flutter doctor` — без
  замечаний. Android: cmdline-tools 23.0 + `JAVA_HOME` → Android Studio JBR.
  До 2026-10-24 VS на этой машине отсутствовал: записи о «локальной сборке»
  от 2026-10-22 относились к другому ПК (см. `docs/debug/log.md`).
- **Ветка:** `master`; проверенный код — `07fa5b9`, документация ревью №3 —
  следующий коммит после него; код исправлений ревью №2 — `a50d972` и
  `92a9642`; исправления первого ревью — `8956179`; базовая реализация
  stage-02 — `82b04a2`; HEAD до stage-02 — `6faeb90`.

## Активные фича-флаги
- experimental.llmChat = true (заготовка, не используется)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Что сделано на stage-02

### Схема и напоминания
- Drift schema v3: `tasks.reminder_sent_at` + индекс
  `idx_tasks_remind(remind_at, reminder_sent_at)`.
- Явная миграция `v2 → v3`; `v1 → v3` создаёт ядро и FTS5. Guard
  `from > to || from > 3 || to > 3` стоит до DDL: `v2 → v4` не оставляет
  частичную миграцию, downgrade `v4 → v3`/`v3 → v2` не перезаписывает
  `user_version` (R02-004 fixed).
- `TasksRepository.dueReminders` / `markReminderSent`; при изменении
  `remind_at` поле `reminder_sent_at` сбрасывается.
- JSON-backup переносит `reminder_sent_at` (старые файлы — `NULL`).

### Дашборд и навигация
- Дашборд: задачи на сегодня и просроченные (`dueAt ?? remindAt`), последние
  заметки/идеи, финансы за месяц, обновление и пустые состояния.
- Финансы на дашборде считаются только в `FinanceDraft.defaultCurrency`
  (`RUB`): `summary(currency:)`, валюта в подписи каждой ячейки; операции в
  других валютах не смешиваются (R02-011).
- `RefreshIndicator.onRefresh` ждёт `Future<void>` от `_reload()` — индикатор
  не завершается раньше загрузки (R02-012).
- Быстрые действия и переходы «Все» в заметки, задачи, идеи и финансы.
- Границы локального дня/месяца — календарные (`dashboard_period.dart`), без
  `+ Duration(days: 1)`; финансы используют эксклюзивную верхнюю границу
  `[from, to)` (R02-005/R02-008 fixed).
- `RouterController.navigatorKey` доступен для глобальных диалогов.

### Быстрый ввод, трей, хоткей
- Общий `QuickCaptureDialog` для заметки/задачи/идеи/финансовой операции;
  вызывается с дашборда, из трея и по глобальной комбинации (ADR-016).
  Ошибки провайдера/репозитория перехватываются `try/catch/finally`,
  показываются локализованно, `_saving` сбрасывается (R02-006 fixed).
- `DesktopServices`: меню трея («Быстрый ввод», показать/скрыть, выход),
  close-to-tray по крестику, корректный quit; при исключении в настройке трея
  крестик завершает процесс. На Windows иконка грузится по абсолютному пути
  от `Platform.resolvedExecutable`, файл проверяется через
  `File.existsSync()`, а `_trayReady` выставляется только после успешной
  установки иконки и меню (R02-001 fixed).
- `QuickHotkey`: JSON в `app_settings` (`hotkey.quick_capture`), по умолчанию
  `Ctrl+Alt+B`; запись через `HotkeyRecorderDialog`, сохранение и откат в
  `SettingsController`. На старте apply ожидается; при `false` применяется и
  сохраняется default, UI показывает фактическую комбинацию; early return при
  совпадении state удалён (R02-003 fixed).
- **R02-009 fixed (ADR-017):** `hotkey_manager_windows 0.2.0` вендорен в
  `third_party/` и подключён через `dependency_overrides`; нативный
  `Register` проверяет `::RegisterHotKey` и при неудаче возвращает
  `PlatformException(hotkey_busy, …, 1409)`. Dart-откат вынесен в тестируемый
  `DesktopServices.applyHotkeyBinding(...)` (`HotkeyRegistrar`): при ошибке
  возвращается `false`, прежняя комбинация регистрируется снова, UI показывает
  `hotkeyBusyError`. Ручной Windows-сценарий с `tool/occupy_hotkey.ps1`
  подтвердил реальное обнаружение занятой комбинации; смена через UI —
  ручной шаг.
- `ReminderScheduler` проверяет БД сразу и раз в 30 секунд; Windows toast через
  `local_notifier` 0.1.6 (WinToast), на других платформах no-op. `show`
  возвращает `bool`; `reminder_sent_at` ставится только при успехе. Неудачи
  повторяются по backoff **30 с → 1 мин → 5 мин → 15 мин** на задачу, warning
  логируется без спама; если toast уже показан, при сбое отметки повторяется
  только `markReminderSent` (R02-002/R02-010 fixed).
- В редакторе задач — выбор даты/времени напоминания и чип в карточке.

### Локализация
- RU/EN ARB пополнены ключами дашборда, быстрого ввода, трея, хоткея и
  напоминаний; `flutter gen-l10n` выполнен.

### Ручной smoke Windows (2026-10-23, по отчёту agent-1)
- Запуск debug-сборки из корня репозитория, дашборд и быстрые действия
  отрисованы.
- `Ctrl+Alt+B` открывает `QuickCaptureDialog`; `Alt+F4` скрывает окно в трей,
  процесс остаётся жив; повторный хоткей возвращает окно и диалог.
- Временная задача с наступившим `remind_at` дала Windows toast; клик по toast
  показал окно. БД после проверки восстановлена из резервной копии.
- После исправления R02-001 сборка запускалась уже из каталога
  `build\windows\x64\runner\Debug`; `taskkill /PID` без `/F` (WM_CLOSE)
  скрыл окно, процесс остался жив минимум 3 секунды и был остановлен
  принудительно. Файл
  `data\flutter_assets\assets\tray_icon.ico` существует рядом с `.exe`.
- Ограничение: контекстное меню и иконка трея визуально не проверялись
  (иконка может быть скрыта в overflow Windows); smoke не является
  независимым подтверждением (см. review).

### Независимый Windows-smoke ревьюера (2026-10-24, agent-2)
- `.exe` запущен из `build\windows\x64\runner\Debug`; окно открылось.
- В рабочую БД добавлена задача с `remind_at` в прошлом: планировщик записал
  `reminder_sent_at`, через 40 с (следующий тик) значение не изменилось —
  повторной отметки/показа нет; WinToast инициализировался без ошибок.
- `taskkill /PID` без `/F` (WM_CLOSE): процесс жив, `IsWindowVisible = false`
  — close-to-tray работает и косвенно подтверждает, что трей поднят
  (`_trayReady == true`, иначе приложение завершилось бы).
- Меню/иконка трея и сам toast визуально не проверялись; физическое нажатие
  хоткея не эмулировалось.

### Ручной сценарий занятой комбинации (2026-10-24, agent-1)

- `tool/occupy_hotkey.ps1` занял `Ctrl+Alt+B`; при запуске приложение получило
  `PlatformException(hotkey_busy, RegisterHotKey failed: the shortcut is
  already in use, 1409, null)`, продолжило работу и залогировало неудачное
  применение сохранённой комбинации.
- После остановки helper'а регистрация прошла:
  `DesktopServices: горячая клавиша Ctrl + Alt + B зарегистрирована`.
- В собранной DLL присутствует строка `hotkey_busy` — используется
  пропатченный плагин.
- Смена комбинации через настройки и SnackBar в GUI вручную не прокликивались;
  логика отката покрыта unit-тестами.

## Известные ограничения / принятый техдолг
- **R02-009…R02-013 — fixed** (2026-10-24, `a50d972`/`92a9642`); отчёт:
  [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
  Ревью №3 — **PASS WITH COMMENTS**: MAJOR нет; R02-014 (MINOR, сводка экрана
  финансов всё ещё смешивает валюты) и R02-015 (NIT, повторный error-лог при
  сбое `markReminderSent`) не блокируют stage-03.
- TD-15 (хоткей не настраивался) — **fixed** на stage-02 (ADR-016, ADR-017).
- TD-27 (занятая комбинация не обнаруживалась) — **fixed** (ADR-017).
- TD-21 (MAJOR, accepted): сумма финансов — `REAL`/`double`, возможны
  погрешности; триггер — бюджеты/аналитика.
- TD-22 (MINOR, accepted): нет `User`, вложений, learning/chat-таблиц.
- TD-23 (MINOR, accepted): экспорт/импорт через ввод пути, без file-picker.
- TD-24 (MINOR, accepted): нет UI корзины/restore/purge для soft-delete.
- TD-25 (MINOR, accepted): напоминания работают только пока запущен процесс
  приложения (включая трей); нет автозапуска/планировщика ОС.
- TD-26 (MINOR, accepted): клик по toast только показывает окно, но не
  открывает задачу; нет действий «Отложить/Выполнено».
- TD-18/TD-20 остаются accepted: golden-тестов нет; `dart format` не включён в
  CI (шум на legacy-файлах).
- DST-переход (23/25-часовые сутки) локально не воспроизводился; тест
  `dashboard_period_test.dart` проверяет календарную семантику границ.
- Повторное ревью stage-02 №2 (2026-10-24): **FAIL**; все пять находок
  исправлены. Ревью №3 (2026-10-24): **PASS WITH COMMENTS**; stage-03
  разблокирован.

## Ближайшие задачи (stage-03 «LLM-слой»)
- Вердикт ревью №3 получен: **PASS WITH COMMENTS**, открытых MAJOR нет;
  stage-03 можно начинать. R02-014/R02-015 — не блокирующие комментарии.
- Перед релизной проверкой вручную пройти п. 6 чек-листа stage-02 (занятая
  комбинация + SnackBar `hotkeyBusyError`).
- Ревьюеру в stage-03: следить, чтобы `is_private_for_llm` и секреты не попадали
  в LLM-контекст; проверить стриминг и tool-вызовы.
- Провайдеры LLM, чат, стриминг, privacy guard и tool-вызовы по `PROMPT.md`.
- Не отправлять в LLM записи с `is_private_for_llm = true`.
- Решить TD-21 перед финансовой аналитикой/бюджетами.
- По UX-долгу: file-picker (TD-23), корзина (TD-24), golden-тесты (TD-18).

## Последние ключевые ADR
- ADR-001: Riverpod как DI/стейт
- ADR-002: Drift, схема v1 (app_settings)
- ADR-003: SecretStore через flutter_secure_storage
- ADR-006: tray_manager пин 0.5.0
- ADR-009: сборка Windows проверяется в CI
- ADR-010: локализация трея/заголовка окна через ARB
- ADR-011: отказ от sqlite3_flutter_libs (sqlite3 3.x + hooks)
- ADR-012: политика миграций — без createAll в onUpgrade
- ADR-013: FTS5 отдельной таблицей + ручная индексация
- ADR-014: JSON-импорт заменяет, CSV финансов добавляет
- ADR-015: схема v3 и `reminder_sent_at` для идемпотентных напоминаний
- ADR-016: быстрый ввод — общий диалог, хоткей и трей
- ADR-017: вендорный патч `hotkey_manager_windows` — проверка занятой
  комбинации

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; ревью stage-02 —
  **FAIL** (2 MAJOR, 6 MINOR); повторное ревью №2 (2026-10-24) — **FAIL**
  (1 MAJOR R02-009, 2 MINOR, 2 NIT); повторное ревью №3 (2026-10-24) —
  **PASS WITH COMMENTS** (0 MAJOR, 1 MINOR R02-014, 1 NIT R02-015);
  ревью stage-01 не проводилось.

## Ссылки
- Отчёт stage-02: [stages/stage-02.md](stages/stage-02.md)
- Отчёт stage-01: [stages/stage-01.md](stages/stage-01.md)
- Отчёт stage-00: [stages/stage-00.md](stages/stage-00.md)
- Ревью stage-02: [reviews/stage-02-review.md](reviews/stage-02-review.md)
- Результаты исправлений stage-02 R02-001…R02-008:
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md)
- Результаты исправлений stage-02 R02-009…R02-013:
  [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md)
- Ревью stage-00: [reviews/stage-00-review.md](reviews/stage-00-review.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md)
- ADR: [decisions.md](decisions.md)
- Журнал дебага: [debug/log.md](debug/log.md)

## Репозиторий
- Удалённый: **https://github.com/HoudiwinG/second-brain** (приватный), ветка master
- HEAD до stage-02: `6faeb90` (`fix(stage-01): убрать overflow бокового rail
  при низком окне`).
- Stage-02: `82b04a2`; исправления ревью — `8956179`; исправления повторного
  ревью №2 — `a50d972`, `92a9642`. CI runs stage-02:
  [39919792561](https://github.com/HoudiwinG/second-brain/actions/runs/39919792561)
  (`82b04a2`),
  [39920666645](https://github.com/HoudiwinG/second-brain/actions/runs/39920666645)
  (`296970b`),
  [39931858624](https://github.com/HoudiwinG/second-brain/actions/runs/39931858624)
  (`e8c6005`, включает `8956179`),
  [40091767297](https://github.com/HoudiwinG/second-brain/actions/runs/40091767297)
  (`f9511c0`),
  [40095276919](https://github.com/HoudiwinG/second-brain/actions/runs/40095276919)
  (`92a9642`) — все **success** (проверено `gh run list`).
- CI: GitHub Actions (`.github/workflows/ci.yml`) — pub get
  `--enforce-lockfile` + analyze + test (ubuntu) + test + build windows
  --debug (windows-latest).
- Секреты: `.env` исключён; в репозитории только `.env.example`.
