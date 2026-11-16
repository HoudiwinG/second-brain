# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-05 (обучение) — **реализация и self-check готовы,
  независимое ревью ещё не проводилось.** Треки, roadmap-шаги, сессии,
  AI-тренер (roadmap/материалы/check-in), приватный трек не уходит в LLM.
  Analyze 0, test **185/185**, Windows debug build success. Отчёт:
  [stages/stage-05.md](stages/stage-05.md); ADR-022; схема **v7**
  (`learning_tracks`, `learning_sessions`).
- **Предыдущий этап:** stage-04 (инструменты ассистента) — **PASS WITH
  COMMENTS (0 MAJOR)**. Все S04R/S04F/S04Z fixed; analyze 0, test 172/172,
  Windows debug build success. Отчёт: [stages/stage-04.md](stages/stage-04.md),
  финальное ревью: [reviews/stage-04-final-review.md](reviews/stage-04-final-review.md).
- **Stage-03 (LLM-слой)** закрыт повторным независимым ревью **PASS**
  (2026-10-28), 28/28 verified. Исходное ревью остаётся **FAIL** (2026-10-25).
- **Статус stage-02:** **PASS WITH COMMENTS** (ревью №3); R02-001…R02-013
  закрыты, R02-014 (MINOR, сводка экрана финансов) и R02-015 (NIT, error-лог
  retry) остаются не блокирующими комментариями.
- **Статус stage-03:** провайдеры OpenAI-compatible/Anthropic/Google,
  безопасные ключи в `SecretStore`, streaming-чат с отменой/повтором и
  офлайн-историей, privacy guard с флагами из БД, контракт tools и интерфейсы
  RAG. Схема БД — **v5** (`embedding_model`, `is_private_for_llm`, partial
  unique index default). Локальные гейты после исправлений зелёные: analyze
  **No issues found**, test **132/132**, Windows debug build **success**
  (2026-10-28); CI-run
  [40636764573](https://github.com/HoudiwinG/second-brain/actions/runs/40636764573)
  (`49bc00f`, включающий `14e63a7`) — **success**.
- **Исходное ревью stage-03:** [reviews/stage-03-review.md](reviews/stage-03-review.md) —
  **FAIL**: reviewer A — 2 major/9 minor/6 nit, reviewer B — 2 major/13 minor/
  4 nit; после объединения дублей — 3 major, 17 minor, 8 nit. Вердикт и история
  сохранены без изменений.
- **Повторное ревью stage-03:** [reviews/stage-03-repeat-review.md](reviews/stage-03-repeat-review.md)
  — **PASS**: все 28 исходных находок verified; новых блокеров нет
  (0 critical, 0 major, 2 minor S03R-001/S03R-002, 2 nit S03R-003/S03R-004).
- **Исправления stage-03:** [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md)
  — доказательства по каждому S03-ID; все 28 закрыты, новых TD не заведено.
- **Исходное ревью stage-04:** [reviews/stage-04-review.md](reviews/stage-04-review.md)
  — **FAIL** (2026-10-29): 0 critical, 1 major (`S04-001`), 7 minor, 1 nit;
  все 9 находок исправлены в `821b4f8`.
- **Повторное ревью stage-04:** [reviews/stage-04-repeat-review.md](reviews/stage-04-repeat-review.md)
  — **FAIL** (2026-11-16, два прохода): 0 critical, **3 major**, 5 minor,
  3 nit после объединения дублей. Блокеры: `S04R-001`, `S04R-002`,
  `S04R-003`. Исходные S04-001…S04-009 закрыты.
- **Исправления после повторного ревью stage-04:** все 11 находок
  `S04R-001…S04R-011` fixed, повторная проверка — **PASS WITH COMMENTS**;
  комментарии `S04F` fixed, финальная проверка — **PASS WITH COMMENTS**
  (0 MAJOR), S04Z fixed, тесты 172/172 —
  [stage-04-repeat-fix-results.md](reviews/stage-04-repeat-fix-results.md),
  [stage-04-final-review.md](reviews/stage-04-final-review.md).
- **Последний PASS-ревью:** stage-03 —
  [reviews/stage-03-repeat-review.md](reviews/stage-03-repeat-review.md),
  **PASS** (2026-10-28, 28/28 verified, 0 major). Stage-02 —
  [reviews/stage-02-review.md](reviews/stage-02-review.md),
  **PASS WITH COMMENTS** (ревью №3, 2026-10-24); исторические вердикты
  **FAIL** (ревью и повторное №2). Результаты исправлений R02-001…R02-008 —
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md),
  R02-009…R02-013 — [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
- **Текущий отчёт:** [stages/stage-05.md](stages/stage-05.md)
- **Открытых CRITICAL:** 0
- **Stage-05:** реализация и self-check готовы, независимое ревью ещё не
  проводилось; блокеров нет. **Stage-04:** PASS WITH COMMENTS, все S04R/
  S04F/S04Z fixed. **Открытых исходных S03-находок:** 0 (28/28 подтверждены
  повторным ревью). **Не блокирующие комментарии:** S03R-001/S03R-002
  (MINOR), S03R-003/S03R-004 (NIT), R02-014 (MINOR), R02-015 (NIT).
  **Принятый TD:** TD-28 (нет UI выбора контекста; триггер перенесён на
  позднюю доработку чата). TD-21 — отдельное принятое ограничение `REAL` для
  финансов.
- **Сборка:** `flutter analyze --fatal-infos` — **No issues found**;
  `flutter test` — **185/185**; `flutter build windows --debug` — **success**
  (2026-11-16, `build\windows\x64\runner\Debug\second_brain.exe`); CI-run
  `43892374452` (`9b96f58`) — success, включая Windows debug build.
- **Flutter SDK:** 3.47.7 stable, `C:\src\flutter` (Dart 3.13.5)
- **Windows-тулчейн:** Visual Studio Build Tools 2022 17.14 (MSVC v143 +
  Windows SDK + ATL/ATLMFC), установлен 2026-10-24; `flutter doctor` — без
  замечаний. Android: cmdline-tools 23.0 + `JAVA_HOME` → Android Studio JBR.
  До 2026-10-24 VS на этой машине отсутствовал: записи о «локальной сборке»
  от 2026-10-22 относились к другому ПК (см. `docs/debug/log.md`).
- **Ветка:** `master`; stage-04 закрыт на `9f54bcc` (комментарии S04F),
  документация — `5202cc1`/`326299c`; stage-05 — `9b96f58`. Базовая
  реализация stage-03 — `0ae0c85`, отчёт stage-03 — `0defdb0`, уточнение
  отчёта — `9fedec7`, независимое ревью — `6906c2d`, исправления S03 —
  `14e63a7`, документация исправлений — `49bc00f` и `3089b79`, повторное
  ревью stage-03 — `0e72495`. Код исправлений ревью №2 stage-02 — `a50d972`
  и `92a9642`; исправления первого ревью — `8956179`; базовая реализация
  stage-02 — `82b04a2`; HEAD до stage-02 — `6faeb90`.

## Активные фича-флаги
- experimental.llmChat = true (чат и LLM-провайдеры используются на stage-03)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Что сделано на stage-03

> **Ревью 2026-10-25:** исходный вердикт — **FAIL**; он сохранён в
> [reviews/stage-03-review.md](reviews/stage-03-review.md). Все 28 находок
> исправлены коммитом `14e63a7`, доказательства —
> [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md).
> **Повторное ревью 2026-10-28 — PASS** (28/28 verified), см.
> [reviews/stage-03-repeat-review.md](reviews/stage-03-repeat-review.md).
> Stage-04 разблокирован; S03R-001…S03R-004 остаются неблокирующими
> комментариями.

### Схема v5 и секреты
- `schemaVersion = 5`; таблицы `llm_provider_configs`, `chat_threads`,
  `chat_messages` (ADR-018). Добавлены `embedding_model` (nullable) и
  `is_private_for_llm` (default false); `max_tokens` — 1…32768, default 1024.
- Инвариант «ровно один default» поддерживается репозиторием и partial unique
  index `idx_llm_configs_default ... WHERE is_default = 1`; миграция
  нормализует старые 0/2 default.
- API-ключ не попадает в БД: только `secret_ref` в `SecretStore`; при
  удалении конфигурации треды сохраняются с `provider_config_id = NULL`.
- Явные миграции `v3 → v4`, `v4 → v5`, `v1/v2 → v5`; guard
  `from > to || from > 5 || to > 5` до DDL; индексы создаются после таблиц.
- Компенсация: при ошибке записи конфигурации ключ удаляется или
  восстанавливается; `maxTokens` и base URL валидируются в репозитории.

### Сеть и провайдеры
- `ApiClient` — реальный `http 1.6.0`: `sendStreamed`, `requestJson`,
  `streamLines`, таймауты 15/60 с. `maxRetries = 3` — **3 попытки всего**
  (первая + два повтора), паузы 200 и 400 мс (ADR-019).
- Retry только до начала SSE-потока; после старта повтор запрещён, чтобы не
  дублировать текст. Ошибка после partial-ответа сохраняет текст с
  `error_code = 'llm_error'` и исключает его из следующего запроса.
- Адаптеры: OpenAI/OpenAI-compatible (`/chat/completions`,
  `/embeddings`), Anthropic (`/messages`), Google
  (`:streamGenerateContent?alt=sse`, `:embedContent`).
- `embeddingModel` — отдельная модель: явное значение конфигурации, затем
  провайдерский default (`text-embedding-3-small`/`nomic-embed-text`/
  `text-embedding-004`). Anthropic embeddings не поддерживает.
- OpenAI-compatible при 400/422 повторяет запрос без `stream_options` для
  старых Ollama/vLLM.
- Финальный `done`-чанк содержит накопленный usage, если провайдер его вернул;
  иначе `usage == null`. Anthropic объединяет usage из `message_start` и
  `message_delta`.
- Tool-call-дельты парсятся в `LlmResponse.toolCalls`, но не исполняются.

### Чат и история
- `ChatController`: загрузка тредов/сообщений из БД, новый/выбранный/удалённый
  тред, streaming, отмена, `retryLast`, сохранение usage и маркеров ошибок.
- `sendMessage` возвращает `Future<bool>`; старый `llm_error` не блокирует
  отправку, а синхронный `_sending` guard не пропускает параллельный вызов.
- У запроса есть `requestId`; callbacks проверяют активный тред. Создание,
  выбор или удаление треда во время streaming сначала отменяет запрос и
  сохраняет partial-ответ.
- История запроса строится `buildChatRequestMessages`: последние 40 сообщений,
  не более 60 000 символов с контекстом, без ведущего `assistant`, со склейкой
  одинаковых ролей и без приватных/ошибочных сообщений.
- Завершённый ответ сохраняется целиком; при отмене — уже полученный
  фрагмент; пустой ответ — маркер `cancelled`, ошибка — `llm_error` без тела
  провайдера.
- `cancel()` не ждёт закрытия HTTP-потока, чтобы UI не зависал.
- История доступна офлайн; при перезапуске открывается последний тред.
- UI: список тредов, лента сообщений, индикатор streaming, кнопка Stop,
  повтор для `llm_error`, пометка сообщения приватным; без провайдера
  отключается только composer, история остаётся видимой.

### Настройки LLM
- `LlmSettingsSection`: CRUD провайдеров, тип, имя, base URL, чат- и
  embedding-модель, ключ, лимит токенов, default, удаление, локализованные
  SnackBar.
- Ключ при редактировании можно не менять; явная кнопка удаляет сохранённый
  ключ; в UI показывается только «ключ сохранён/не задан».
- Форма валидирует обязательные поля, `maxTokens` и base URL до сохранения;
  при ошибке диалог не закрывается и ввод не теряется.
- Для удалённых хостов требуется `https`, `http` разрешён только для
  loopback.

### Privacy guard, tools, RAG
- Вызывающий код передаёт только `LlmContextRef(type, id)`;
  `DriftLlmContextLoader` читает содержимое и `isPrivateForLlm` из БД, поэтому
  флаг нельзя подделать из UI. `PrivacyGuard.filter` исключает приватные
  сущности и логирует только количество/типы, без содержимого.
- У сообщений чата есть `is_private_for_llm`; такие сообщения и error-маркеры
  не попадают в следующий запрос.
- `LlmToolRegistry`/`LlmTool` — контракт и реестр; на stage-03 реестр был
  пуст, на stage-04 заполнен встроенными инструментами. Имена trim-ятся
  единообразно.
- `EmbeddingService` и `VectorStore` — интерфейсы RAG, без индексации.
- В чате пока нет UI выбора контекста (TD-28), но production-путь
  `sendMessage(contextRefs:)` покрыт тестами.

## Что сделано на stage-05

- Схема **v7**: `learning_tracks` (title, goal, JSON roadmap/custom fields,
  private flag, soft-delete) и `learning_sessions` (track FK, duration,
  notes, date); индексы по updated_at и track/date.
- `LearningRepository`: CRUD треков, замена шагов, смена статуса шага,
  сессии, forLlm-фильтр.
- `LearningTrainer`: roadmap по цели через default LLM-провайдера, материалы
  и check-in; приватный трек не отправляется, ключи — из secure storage.
- UI: список треков, редактор, детали с roadmap/сессиями, AI-панель,
  check-in баннер при отсутствии сессии более 3 дней.
- Тесты: 185/185, analyze 0, Windows debug build success. Независимое ревью
  stage-05 ещё не проводилось.

## Что сделано на stage-04

### Инструменты и tool loop
- Встроенные инструменты: `create_task` (с `remind_at`), `create_note`,
  `update_task_status`, `search_data`, `summarize_mail_mock`.
- `ToolRunner`: неизвестный инструмент, битый JSON и ошибка валидации не
  прерывают запрос; модель получает `{"ok": false, "error": ...}`.
- `ChatController` выполняет tool calls раундами, лимит `maxToolRounds = 3`;
  при превышении — `llm_error`/`tool_side_effect` с сохранением
  partial-текста. Отмена останавливает следующий раунд, но уже выполненные
  инструменты не откатываются.
- Провайдеры: OpenAI-compatible `tool_calls`/`tool`, Anthropic
  `tool_use`/`tool_result` с группировкой параллельных результатов, Google
  `functionCall`/`functionResponse` с сохранением `functionCall.id`.
- Аудит: схема **v6**, `tool_audit_log` (`ToolAuditEntries`); пишутся имя
  инструмента, статус, имена аргументов без значений, `entity_id`, время.
- После успешного mutating-инструмента обычный Retry запрещён
  (`tool_side_effect`); полностью идемпотентный повтор не реализован.
- Тесты stage-04: **172/172**; analyze 0; Windows debug build success.

## Что сделано на stage-02

### Схема и напоминания
- Drift schema v3: `tasks.reminder_sent_at` + индекс
  `idx_tasks_remind(remind_at, reminder_sent_at)`.
- Явная миграция `v2 → v3`; `v1 → v3` создаёт ядро и FTS5. Guard
  `from > to || from > 3 || to > 3` стоит до DDL: `v2 → v5` не оставляет
  частичную миграцию, downgrade `v5 → v3`/`v3 → v2` не перезаписывает
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
- **Stage-05 — self-check (2026-11-16).** Треки, roadmap, сессии, AI-тренер
  и схема v7 готовы; analyze 0, test 185/185, Windows debug build success.
  Независимое ревью ещё не проводилось. Живые LLM-вызовы тренера не
  выполнялись; roadmap-парсер ограничен JSON-массивом и 20 шагами.
- **Stage-04 — PASS WITH COMMENTS (2026-11-16).** Все `S04R-001…S04R-011`
  fixed; повторная проверка — PASS WITH COMMENTS, комментарии `S04F`/`S04Z`
  fixed. Гейты: analyze 0, test **172/172**, Windows debug build success; CI
  `43833493988` — success.
- **Stage-03 — исходное ревью FAIL (2026-10-25) сохранено, повторное — PASS
  (2026-10-28).** Все 28 находок S03-001…S03-028 исправлены в `14e63a7` и
  подтверждены. S03R-001/S03R-002 (MINOR) и S03R-003/S03R-004 (NIT) —
  неблокирующие комментарии.
- Все адаптеры проверены через `MockClient`; реальный запрос с настоящим
  API-ключом и ручной GUI-streaming после исправлений не выполнялись.
- **TD-28 (MINOR, accepted):** в чате нет UI выбора контекста; production-путь
  `ChatController.sendMessage(contextRefs:)` читает флаги из БД и покрыт
  тестами, но обычный пользователь пока не может прикрепить заметку/задачу.
  Триггер stage-04 не выполнен; вопрос перенесён на позднюю доработку чата
  (stage-06+), не входит в stage-05.
- Инструменты исполняются, но tool calls/результаты не сохраняются в
  `chat_messages`; трассировка — только в `tool_audit_log`. Поэтому после
  успешного mutating-инструмента обычный Retry запрещён; полная
  идемпотентность повторного выполнения не реализована.
- RAG: только интерфейсы `EmbeddingService`/`VectorStore`, индексации нет.
- Модель вводится вручную; списка моделей от провайдера нет.
- Retry после начала SSE-потока не выполняется; partial-ответ сохраняется с
  маркером ошибки, повтор инициирует пользователь.
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
  закрыты схемой v5.
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

## Ближайшие задачи (stage-06)
- **Stage-06 — почта**: OAuth Gmail/Yandex/Mail.ru, просмотр/поиск,
  суммаризация письма/треда через LLM, создание задачи из письма; флаг
  приватности на уровне ящика/письма; refresh-токены только в secure storage.
- Провести независимое ревью stage-05; после PASS — stage-06.
- Учесть неблокирующие S03R-001…S03R-004 и S04Z.
- TD-28 (UI выбора контекста) — отдельная поздняя доработка чата.
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
- ADR-018: схема v5 — LLM-конфигурации, embedding/private-поля, partial unique
  default, офлайн-чат и секреты вне БД
- ADR-019: HTTP/SSE-транспорт через `ApiClient`, 3 попытки всего, retry только
  до потока
- ADR-020: единый контракт LLM, streaming, privacy guard через `LlmContextRef`
  и границы tools/RAG
- ADR-021: инструменты ассистента, tool loop, аудит без содержимого и
  приватность результатов
- ADR-022: обучение — треки, JSON roadmap, сессии и AI-тренер

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; ревью stage-02 —
  **FAIL** (2 MAJOR, 6 MINOR); повторное ревью №2 (2026-10-24) — **FAIL**
  (1 MAJOR R02-009, 2 MINOR, 2 NIT); повторное ревью №3 (2026-10-24) —
  **PASS WITH COMMENTS** (0 MAJOR, 1 MINOR R02-014, 1 NIT R02-015);
  независимое ревью stage-03 (reviewer A, 2026-10-25) — **FAIL**
  (2 MAJOR, 9 MINOR, 6 NIT); исправления S03 — agent-1 (`14e63a7`); ревью
  stage-01 не проводилось.
- agent-3: независимое ревью stage-03 (reviewer B, 2026-10-25) — **FAIL**
  (2 MAJOR, 13 MINOR, 4 NIT).
- independent repeat reviewer (Gemini 4 Argon, 2026-10-28): повторное ревью
  stage-03 — **PASS**, 28/28 verified, 0 critical/0 major; S03R-001…S03R-004
  неблокирующие. Stage-04 разблокирован.
- reviewer A (agent-2, 2026-11-07): повторное ревью stage-04 — **FAIL**
  (2 MAJOR, 3 MINOR, 2 NIT); reviewer B (agent-3, 2026-11-07): **FAIL**
  (3 MAJOR, 3 MINOR, 1 NIT); после объединения — 3 MAJOR, 5 MINOR, 3 NIT.
  agent-1 (2026-11-16): stage-04 закрыт PASS WITH COMMENTS; stage-05
  (обучение) реализован, гейты 185/185, ожидается независимое ревью.

## Ссылки
- Отчёт stage-05: [stages/stage-05.md](stages/stage-05.md)
- ADR-022: [decisions.md](decisions.md) — обучение, JSON roadmap, AI-тренер
- Отчёт stage-04: [stages/stage-04.md](stages/stage-04.md)
- Исходное ревью stage-04:
  [reviews/stage-04-review.md](reviews/stage-04-review.md)
- Повторное ревью stage-04:
  [reviews/stage-04-repeat-review.md](reviews/stage-04-repeat-review.md)
- Исправления после повторного ревью:
  [reviews/stage-04-repeat-fix-results.md](reviews/stage-04-repeat-fix-results.md)
- Результаты исправлений stage-04:
  [reviews/stage-04-fix-results.md](reviews/stage-04-fix-results.md)
- Отчёт stage-03: [stages/stage-03.md](stages/stage-03.md)
- Ревью stage-03: [reviews/stage-03-review.md](reviews/stage-03-review.md)
- Повторное ревью stage-03:
  [reviews/stage-03-repeat-review.md](reviews/stage-03-repeat-review.md)
- Результаты исправлений stage-03:
  [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md)
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
- Stage-03: `0ae0c85` — базовая реализация (провайдеры, чат, privacy guard,
  схема v4); `9fedec7` — уточнение отчёта; `6906c2d` — независимое ревью;
  `14e63a7` — исправления S03-001…S03-028 (схема v5, 132 теста); документация
  исправлений — `49bc00f`, `3089b79`; документация повторного ревью — коммит
  после `3089b79`.
- CI stage-03 (базовая реализация): run
  [40112234645](https://github.com/HoudiwinG/second-brain/actions/runs/40112234645)
  (`0ae0c85`) — `analyze-and-test` и `build-windows` **success**
  (проверено через `gh run watch`). CI исправлений:
  [40636764573](https://github.com/HoudiwinG/second-brain/actions/runs/40636764573)
  (`49bc00f`, включающий `14e63a7`) — **success** (оба job'а).
- CI: GitHub Actions (`.github/workflows/ci.yml`) — pub get
  `--enforce-lockfile` + analyze + test (ubuntu) + test + build windows
  --debug (windows-latest).
- Секреты: `.env` исключён; в репозитории только `.env.example`.
