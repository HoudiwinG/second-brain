# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-03 (LLM-слой) завершён — **done (self-check)**;
  независимое ревью stage-03 не проводилось; следующий — stage-04
  (инструменты ассистента).
- **Статус stage-02:** **PASS WITH COMMENTS** (ревью №3); R02-001…R02-013
  закрыты, R02-014 (MINOR, сводка экрана финансов) и R02-015 (NIT, error-лог
  retry) остаются не блокирующими комментариями.
- **Статус stage-03:** провайдеры OpenAI-compatible/Anthropic/Google,
  безопасные ключи в `SecretStore`, streaming-чат с отменой и офлайн-историей,
  privacy guard, контракт tools и интерфейсы RAG. Локально: analyze 0, test
  **104/104**, Windows debug build success (2026-10-24); CI-run
  [40112234645](https://github.com/HoudiwinG/second-brain/actions/runs/40112234645)
  для `0ae0c85` — **success** (проверено через `gh`).
- **Последний ревью-этап:** stage-02 — [reviews/stage-02-review.md](reviews/stage-02-review.md),
  **PASS WITH COMMENTS** (ревью №3, 2026-10-24); исторические вердикты
  **FAIL** (ревью и повторное №2). Результаты исправлений R02-001…R02-008 —
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md),
  R02-009…R02-013 — [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
- **Текущий отчёт:** [stages/stage-03.md](stages/stage-03.md)
- **Открытых CRITICAL:** 0
- **Открытых MAJOR:** 0; **MINOR:** 2 (R02-014 — экран финансов; TD-28 — нет
  UI выбора контекста в чате); **NIT:** 1 (R02-015, лог retry). TD-21 —
  отдельное принятое ограничение `REAL` для финансов.
- **Сборка:** `flutter analyze --fatal-infos` — 0 issues;
  `flutter test` — **104/104**; `flutter build windows --debug` — **success**
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
- experimental.llmChat = true (чат и LLM-провайдеры используются на stage-03)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Что сделано на stage-03

### Схема v4 и секреты
- `schemaVersion = 4`; добавлены `llm_provider_configs`, `chat_threads`,
  `chat_messages` (ADR-018). `max_tokens` хранится в конфигурации (1…32768,
  default 1024).
- API-ключ не попадает в БД: только `secret_ref` в `SecretStore`; при
  удалении конфигурации треды сохраняются с `provider_config_id = NULL`.
- Явные миграции `v3 → v4` и `v1 → v4`; guard `from > to || from > 4 ||
  to > 4` до DDL; индексы создаются после всех таблиц.
- Teardown/компенсация: при ошибке записи конфигурации ключ удаляется или
  восстанавливается; `maxTokens` валидируется в репозитории.

### Сеть и провайдеры
- `ApiClient` — реальный `http 1.6.0`: `sendStreamed`, `requestJson`,
  `streamLines`, таймауты 15/60 с, до 3 попыток (ADR-019).
- Retry только до начала SSE-потока; после старта повтор запрещён, чтобы не
  дублировать текст.
- Адаптеры: OpenAI/OpenAI-compatible (`/chat/completions`,
  `/embeddings`), Anthropic (`/messages`), Google
  (`:streamGenerateContent?alt=sse`, `:embedContent`).
- Финальный `done`-чанк всегда содержит накопленный usage; Anthropic
  объединяет usage из `message_start` и `message_delta`.
- Tool-call-дельты парсятся в `LlmResponse.toolCalls`, но не исполняются.

### Чат и история
- `ChatController`: загрузка тредов/сообщений из БД, новый/выбранный/удалённый
  тред, streaming, отмена, сохранение usage и маркеров ошибок.
- Завершённый ответ сохраняется целиком; при отмене — уже полученный
  фрагмент, при пустом ответе/ошибке — маркер `cancelled`/`llm_error` без
  тела провайдера.
- `cancel()` не ждёт закрытия HTTP-потока, чтобы UI не зависал.
- История доступна офлайн; при перезапуске открывается последний тред.
- UI: список тредов, лента сообщений, индикатор streaming, кнопка Stop,
  пустое состояние с переходом в настройки.

### Настройки LLM
- `LlmSettingsSection`: CRUD провайдеров, тип, имя, base URL, модель, ключ,
  лимит токенов, default, удаление, локализованные SnackBar.
- Ключ при редактировании можно не менять; пустая строка удаляет его; в UI
  показывается только факт «ключ сохранён», не сам ключ.

### Privacy guard, tools, RAG
- `PrivacyGuard.filter` исключает `isPrivateForLlm = true`; логирует только
  количество и типы, без содержимого; вызывается в
  `ChatController.sendMessage(context:)`.
- `LlmToolRegistry`/`LlmTool` — контракт и реестр; на stage-03 реестр пуст,
  определения передаются в запрос.
- `EmbeddingService` и `VectorStore` — интерфейсы RAG, без индексации.
- В чате пока нет UI выбора контекста (TD-28).

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
  подтвердил реальное обнаружение занятой комбинации; смена через UI
  проверена пользователем 2026-10-24 — SnackBar и откат работают.
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
- Смена комбинации через настройки и SnackBar в GUI проверены пользователем
  2026-10-24: занятая комбинация дала локализованную ошибку, откат сработал,
  после освобождения хоткей зарегистрировался и работает.

## Известные ограничения / принятый техдолг
- **Stage-03 — self-check, независимого ревью нет.** Все адаптеры проверены
  через `MockClient`; реальный запрос с настоящим API-ключом и ручной
  GUI-streaming в этом проходе не выполнялись. Это главный пункт для ревью
  stage-03.
- **TD-28 (MINOR, accepted):** в чате нет UI выбора контекста; privacy guard
  вызывается через `ChatController.sendMessage(context:)` и покрыт тестами,
  но обычный пользователь пока не может прикрепить заметку/задачу.
- Tool calls парсятся, но не исполняются; реестр инструментов пуст до
  stage-04.
- RAG: только интерфейсы `EmbeddingService`/`VectorStore`, индексации нет.
- Модель вводится вручную; списка моделей от провайдера нет.
- Retry после начала SSE-потока не выполняется; частичный ответ сохраняется,
  повтор инициирует пользователь.
- Anthropic не поддерживает embeddings; для RAG нужен OpenAI-compatible или
  Google.
- История чата хранится в локальной БД в открытом виде, как и остальные
  данные; шифрование полей через `CryptoService` — отдельный этап.
- **R02-009…R02-013 — fixed** (2026-10-24, `a50d972`/`92a9642`); отчёт:
  [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
  Ревью №3 — **PASS WITH COMMENTS**: MAJOR нет; R02-014 (MINOR, сводка экрана
  финансов всё ещё смешивает валюты) и R02-015 (NIT, повторный error-лог при
  сбое `markReminderSent`) не блокируют stage-03.
- TD-15 (хоткей не настраивался) — **fixed** на stage-02 (ADR-016, ADR-017).
- TD-16 (`ApiClient` без HTTP) — **fixed** на stage-03 (ADR-019).
- TD-27 (занятая комбинация не обнаруживалась) — **fixed** (ADR-017).
- TD-21 (MAJOR, accepted): сумма финансов — `REAL`/`double`, возможны
  погрешности; триггер — бюджеты/аналитика.
- TD-22 (MINOR, accepted): нет `User`, вложений и learning-таблиц; chat-таблицы
  закрыты схемой v4.
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

## Ближайшие задачи (stage-04 «Инструменты ассистента»)
- Провести независимое ревью stage-03; отдельно проверить реальный streaming
  с ключом, отсутствие секретов в БД/логах и privacy guard.
- Реализовать tools: создание задач/заметок/напоминаний, поиск по данным,
  обновление трекера; подключить `LlmToolRegistry` к чату и добавить
  аудит действий без содержимого приватных полей.
- Добавить UI выбора контекста в чат (TD-28), чтобы privacy guard был
  достижим в пользовательском сценарии.
- RAG: реализация `EmbeddingService`/`VectorStore` и индексация заметок.
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
- ADR-018: схема v4 — LLM-конфигурации, офлайн-чат и секреты вне БД
- ADR-019: HTTP/SSE-транспорт через `ApiClient`, retry только до потока
- ADR-020: единый контракт LLM, streaming, privacy guard и границы tools/RAG

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; ревью stage-02 —
  **FAIL** (2 MAJOR, 6 MINOR); повторное ревью №2 (2026-10-24) — **FAIL**
  (1 MAJOR R02-009, 2 MINOR, 2 NIT); повторное ревью №3 (2026-10-24) —
  **PASS WITH COMMENTS** (0 MAJOR, 1 MINOR R02-014, 1 NIT R02-015);
  ревью stage-01 и stage-03 не проводились.

## Ссылки
- Отчёт stage-03: [stages/stage-03.md](stages/stage-03.md)
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
  ревью №2 — `a50d972`, `92a9642`; документация ревью №3 — `1fd60d3`,
  `2e55265`.
- Stage-03: `0ae0c85` — код и тесты (провайдеры, чат, privacy guard, схема
  v4); документация этапа — отдельный коммит после `0ae0c85`.
- CI stage-03: run
  [40112234645](https://github.com/HoudiwinG/second-brain/actions/runs/40112234645)
  (`0ae0c85`) — `analyze-and-test` и `build-windows` **success**
  (проверено через `gh run watch`).
- CI: GitHub Actions (`.github/workflows/ci.yml`) — pub get
  `--enforce-lockfile` + analyze + test (ubuntu) + test + build windows
  --debug (windows-latest).
- Секреты: `.env` исключён; в репозитории только `.env.example`.
