# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-02 (UX-каркас)
- **Статус:** **done**; локальные проверки зелёные, Windows smoke пройден
  (дашборд, хоткей, close-to-tray, toast), код и документация готовы к push.
  CI stage-02 — после push.
- **Последний закрытый этап:** stage-01 (ядро данных) — **done**, CI run
  [39763804171](https://github.com/HoudiwinG/second-brain/actions/runs/39763804171)
  — success.
- **Текущий отчёт:** [stages/stage-02.md](stages/stage-02.md)
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0 (TD-21 — принятое ограничение `REAL` для финансов)
- **Сборка:** `flutter analyze --fatal-infos` — 0 issues;
  `flutter test` — **57/57**; `flutter build windows --debug` — **success**
- **Flutter SDK:** 3.47.7 stable, `C:\src\flutter` (Dart 3.13.5)
- **Ветка:** `master`; HEAD до stage-02 — `6faeb90`.

## Активные фича-флаги
- experimental.llmChat = true (заготовка, не используется)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Что сделано на stage-02

### Схема и напоминания
- Drift schema v3: `tasks.reminder_sent_at` + индекс
  `idx_tasks_remind(remind_at, reminder_sent_at)`.
- Явная миграция `v2 → v3`; `v1 → v3` создаёт ядро и FTS5. Политика ADR-012
  сохранена: непокрытый переход падает с `UnsupportedError`.
- `TasksRepository.dueReminders` / `markReminderSent`; при изменении
  `remind_at` поле `reminder_sent_at` сбрасывается.
- JSON-backup переносит `reminder_sent_at` (старые файлы — `NULL`).

### Дашборд и навигация
- Дашборд: задачи на сегодня и просроченные (`dueAt ?? remindAt`), последние
  заметки/идеи, финансы за месяц, обновление и пустые состояния.
- Быстрые действия и переходы «Все» в заметки, задачи, идеи и финансы.
- `RouterController.navigatorKey` доступен для глобальных диалогов.

### Быстрый ввод, трей, хоткей
- Общий `QuickCaptureDialog` для заметки/задачи/идеи/финансовой операции;
  вызывается с дашборда, из трея и по глобальной комбинации (ADR-016).
- `DesktopServices`: меню трея («Быстрый ввод», показать/скрыть, выход),
  close-to-tray по крестику, корректный quit; при недоступном трее крестик
  завершает процесс.
- `QuickHotkey`: JSON в `app_settings` (`hotkey.quick_capture`), по умолчанию
  `Ctrl+Alt+B`; запись через `HotkeyRecorderDialog`, сохранение и откат в
  `SettingsController`.
- `ReminderScheduler` проверяет БД сразу и раз в 30 секунд; Windows toast через
  `local_notifier` 0.1.6 (WinToast), на других платформах no-op.
- В редакторе задач — выбор даты/времени напоминания и чип в карточке.

### Локализация
- RU/EN ARB пополнены ключами дашборда, быстрого ввода, трея, хоткея и
  напоминаний; `flutter gen-l10n` выполнен.

### Ручной smoke Windows (2026-10-23)
- Запуск debug-сборки, дашборд и быстрые действия отрисованы.
- `Ctrl+Alt+B` открывает `QuickCaptureDialog`; `Alt+F4` скрывает окно в трей,
  процесс остаётся жив; повторный хоткей возвращает окно и диалог.
- Временная задача с наступившим `remind_at` дала Windows toast; клик по toast
  показал окно. БД после проверки восстановлена из резервной копии.

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

## Ближайшие задачи (stage-03 «LLM-слой»)
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
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; ревью stage-01/02 ещё не
  проводилось.

## Ссылки
- Отчёт stage-02: [stages/stage-02.md](stages/stage-02.md)
- Отчёт stage-01: [stages/stage-01.md](stages/stage-01.md)
- Отчёт stage-00: [stages/stage-00.md](stages/stage-00.md)
- Ревью stage-00: [reviews/stage-00-review.md](reviews/stage-00-review.md)
- Реестр техдолга: [tech-debt.md](tech-debt.md)
- ADR: [decisions.md](decisions.md)
- Журнал дебага: [debug/log.md](debug/log.md)

## Репозиторий
- Удалённый: **https://github.com/HoudiwinG/second-brain** (приватный), ветка master
- HEAD до stage-02: `6faeb90` (`fix(stage-01): убрать overflow бокового rail
  при низком окне`).
- Stage-02: коммит и CI-run будут зафиксированы после push.
- CI: GitHub Actions (`.github/workflows/ci.yml`) — pub get
  `--enforce-lockfile` + analyze + test (ubuntu) + test + build windows
  --debug (windows-latest).
- Секреты: `.env` исключён; в репозитории только `.env.example`.
