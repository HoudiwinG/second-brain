# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-02 (UX-каркас)
- **Статус:** исходное ревью — **FAIL** (2 MAJOR, 6 MINOR), но все находки
  R02-001…R02-008 исправлены в коде-коммите `8956179`. Локальные проверки
  зелёные; Windows smoke из каталога `.exe` подтвердил close-to-tray при
  доступной иконке. Ожидается повторное ревью без MAJOR; stage-03 остаётся
  заблокированным до него. CI stage-02:
  [run 39919792561](https://github.com/HoudiwinG/second-brain/actions/runs/39919792561)
  для `82b04a2` заявлен **success** (`analyze-and-test`, `build-windows`),
  независимо не проверен (private repo); CI для `8956179` — после push.
- **Последний закрытый этап:** stage-01 (ядро данных) — **done**, CI run
  [39763804171](https://github.com/HoudiwinG/second-brain/actions/runs/39763804171)
  заявлен success; ревью stage-01 не проводилось.
- **Текущий отчёт:** [stages/stage-02.md](stages/stage-02.md)
- **Текущее ревью:** [reviews/stage-02-review.md](reviews/stage-02-review.md)
  (исторический вердикт **FAIL**) + результаты исправлений:
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md)
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0 по исправлениям (R02-001/R02-002 закрыты
  self-check'ом; формальный вердикт ждёт повторного ревью). TD-21 — отдельное
  принятое ограничение `REAL` для финансов.
- **Сборка:** `flutter analyze --fatal-infos` — 0 issues;
  `flutter test` — **69/69**; `flutter build windows --debug` — **success**
  (2026-10-24, локально, `build\windows\x64\runner\Debug\second_brain.exe`)
- **Flutter SDK:** 3.47.7 stable, `C:\src\flutter` (Dart 3.13.5)
- **Windows-тулчейн:** Visual Studio Build Tools 2022 17.14 (MSVC v143 +
  Windows SDK + ATL/ATLMFC), установлен 2026-10-24; `flutter doctor` — без
  замечаний. Android: cmdline-tools 23.0 + `JAVA_HOME` → Android Studio JBR.
  До 2026-10-24 VS на этой машине отсутствовал: записи о «локальной сборке»
  от 2026-10-22 относились к другому ПК (см. `docs/debug/log.md`).
- **Ветка:** `master`; код исправлений — `8956179`; базовая реализация
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
- `ReminderScheduler` проверяет БД сразу и раз в 30 секунд; Windows toast через
  `local_notifier` 0.1.6 (WinToast), на других платформах no-op. `show`
  возвращает `bool`; `reminder_sent_at` ставится только при успехе, иначе
  повтор на следующем тике (R02-002 fixed).
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

## Известные ограничения / принятый техдолг
- TD-15 (хоткей не настраивался) — **fixed** на stage-02 (ADR-016).
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
- Повторное ревью stage-02 после исправлений R02 ещё не проводилось.

## Ближайшие задачи (stage-03 «LLM-слой»)
- **Сначала** получить повторное ревью stage-02 без MAJOR: все находки
  R02-001…R02-008 исправлены, но независимого вердикта ещё нет. Stage-03 не
  начинать до этого.
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

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; ревью stage-02 —
  **FAIL** (2 MAJOR, 6 MINOR); agent-1 исправил все 8 находок, ожидается
  повторное ревью; ревью stage-01 не проводилось.

## Ссылки
- Отчёт stage-02: [stages/stage-02.md](stages/stage-02.md)
- Отчёт stage-01: [stages/stage-01.md](stages/stage-01.md)
- Отчёт stage-00: [stages/stage-00.md](stages/stage-00.md)
- Ревью stage-02: [reviews/stage-02-review.md](reviews/stage-02-review.md)
- Результаты исправлений stage-02:
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md)
- Ревью stage-00: [reviews/stage-00-review.md](reviews/stage-00-review.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md)
- ADR: [decisions.md](decisions.md)
- Журнал дебага: [debug/log.md](debug/log.md)

## Репозиторий
- Удалённый: **https://github.com/HoudiwinG/second-brain** (приватный), ветка master
- HEAD до stage-02: `6faeb90` (`fix(stage-01): убрать overflow бокового rail
  при низком окне`).
- Stage-02: `82b04a2`; исправления ревью — `8956179`. CI run
  [39919792561](https://github.com/HoudiwinG/second-brain/actions/runs/39919792561)
  для базовой реализации — **success** (`analyze-and-test`, `build-windows`);
  CI для `8956179` проверяется после push.
- CI: GitHub Actions (`.github/workflows/ci.yml`) — pub get
  `--enforce-lockfile` + analyze + test (ubuntu) + test + build windows
  --debug (windows-latest).
- Секреты: `.env` исключён; в репозитории только `.env.example`.
