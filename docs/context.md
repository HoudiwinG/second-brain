# Контекст проекта (снимок состояния)

- **Текущий этап:** stage-03 (LLM-слой). Исходное независимое ревью —
  **FAIL** (2026-10-25, два прохода); все 28 находок S03-001…S03-028
  исправлены коммитом `14e63a7`. **Повторное независимое ревью ещё не
  проводилось**, поэтому формальный вердикт остаётся **FAIL**, а stage-04
  **заблокирован** до его успешного завершения.
- **Статус stage-02:** **PASS WITH COMMENTS** (ревью №3); R02-001…R02-013
  закрыты, R02-014 (MINOR, сводка экрана финансов) и R02-015 (NIT, error-лог
  retry) остаются не блокирующими комментариями.
- **Статус stage-03:** провайдеры OpenAI-compatible/Anthropic/Google,
  безопасные ключи в `SecretStore`, streaming-чат с отменой/повтором и
  офлайн-историей, privacy guard с флагами из БД, контракт tools и интерфейсы
  RAG. Схема БД — **v5** (`embedding_model`, `is_private_for_llm`, partial
  unique index default). Локальные гейты после исправлений зелёные: analyze
  **No issues found**, test **132/132**, Windows debug build **success**
  (2026-10-28); CI-run\n  [40636764573](https://github.com/HoudiwinG/second-brain/actions/runs/40636764573)\n  (`49bc00f`, включающий `14e63a7`) — **success**.
- **Ревью stage-03:** [reviews/stage-03-review.md](reviews/stage-03-review.md) —
  **FAIL**: reviewer A — 2 major/9 minor/6 nit, reviewer B — 2 major/13 minor/
  4 nit; после объединения дублей — 3 major, 17 minor, 8 nit. Исходный вердикт
  и история не переписаны.
- **Исправления stage-03:** [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md)
  — доказательства по каждому S03-ID; все 28 закрыты, новых TD не заведено.
- **Последний PASS-ревью:** stage-02 —
  [reviews/stage-02-review.md](reviews/stage-02-review.md),
  **PASS WITH COMMENTS** (ревью №3, 2026-10-24); исторические вердикты
  **FAIL** (ревью и повторное №2). Результаты исправлений R02-001…R02-008 —
  [reviews/stage-02-review-results.md](reviews/stage-02-review-results.md),
  R02-009…R02-013 — [reviews/stage-02-fix-results.md](reviews/stage-02-fix-results.md).
- **Текущий отчёт:** [stages/stage-03.md](stages/stage-03.md)
- **Открытых CRITICAL:** 0
- **Открытых S03-находок после исправлений:** 0 (28 закрыты, ожидают
  подтверждения повторным ревью). **Не блокирующие комментарии:** R02-014
  (MINOR), R02-015 (NIT). **Принятый TD:** TD-28 (нет UI выбора контекста).
  TD-21 — отдельное принятое ограничение `REAL` для финансов.
- **Сборка:** `flutter analyze --fatal-infos` — **No issues found**;
  `flutter test` — **132/132**; `flutter build windows --debug` — **success**
  (2026-10-28, локально, `build\windows\x64\runner\Debug\second_brain.exe`)
- **Flutter SDK:** 3.47.7 stable, `C:\src\flutter` (Dart 3.13.5)
- **Windows-тулчейн:** Visual Studio Build Tools 2022 17.14 (MSVC v143 +
  Windows SDK + ATL/ATLMFC), установлен 2026-10-24; `flutter doctor` — без
  замечаний. Android: cmdline-tools 23.0 + `JAVA_HOME` → Android Studio JBR.
  До 2026-10-24 VS на этой машине отсутствовал: записи о «локальной сборке»
  от 2026-10-22 относились к другому ПК (см. `docs/debug/log.md`).
- **Ветка:** `master`; базовая реализация stage-03 — `0ae0c85`, отчёт stage-03
  — `0defdb0`, уточнение отчёта — `9fedec7`, независимое ревью — `6906c2d`,
  исправления S03 — `14e63a7`; документация исправлений — следующий коммит.
  Код исправлений ревью №2 stage-02 — `a50d972` и `92a9642`; исправления
  первого ревью — `8956179`; базовая реализация stage-02 — `82b04a2`; HEAD до
  stage-02 — `6faeb90`.

## Активные фича-флаги
- experimental.llmChat = true (чат и LLM-провайдеры используются на stage-03)
- premium.enabled / cloud.sync.enabled / experimental.emailOauth = false

## Что сделано на stage-03

> **Ревью 2026-10-25:** исходный вердикт — **FAIL**; он сохранён в
> [reviews/stage-03-review.md](reviews/stage-03-review.md). Все 28 находок
> исправлены коммитом `14e63a7`, доказательства —
> [reviews/stage-03-fix-results.md](reviews/stage-03-fix-results.md). Этап
> остаётся FAIL, пока независимое повторное ревью не подтвердит исправления.
> Stage-04 до этого заблокирован.

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
- `LlmToolRegistry`/`LlmTool` — контракт и реестр; на stage-03 реестр пуст,
  определения передаются в запрос. Имена trim-ятся единообразно.
- `EmbeddingService` и `VectorStore` — интерфейсы RAG, без индексации.
- В чате пока нет UI выбора контекста (TD-28), но production-путь
  `sendMessage(contextRefs:)` покрыт тестами.

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
- **Stage-03 — исходное ревью FAIL (2026-10-25) сохранено.** Все 28 находок
  S03-001…S03-028 исправлены в `14e63a7`; до успешного независимого повторного
  ревью этап формально остаётся FAIL, stage-04 заблокирован.
- Все адаптеры проверены через `MockClient`; реальный запрос с настоящим
  API-ключом и ручной GUI-streaming после исправлений не выполнялись.
- **TD-28 (MINOR, accepted):** в чате нет UI выбора контекста; production-путь
  `ChatController.sendMessage(contextRefs:)` читает флаги из БД и покрыт
  тестами, но обычный пользователь пока не может прикрепить заметку/задачу.
- Tool calls парсятся, но не исполняются; реестр инструментов пуст до
  stage-04.
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

## Ближайшие задачи (сначала повторное ревью, затем stage-04)
- Запушить `14e63a7` и документацию исправлений; проверить CI
  `analyze-and-test` + `build-windows`.
- Провести независимое повторное ревью stage-03 по
  `stage-03-review.md`/`stage-03-fix-results.md`; исходный FAIL не
  переписывать, новый вердикт оформить отдельно.
- После PASS — stage-04: tools (создание задач/заметок/напоминаний, поиск,
  обновление трекера), аудит действий без содержимого приватных полей.
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
- ADR-018: схема v5 — LLM-конфигурации, embedding/private-поля, partial unique
  default, офлайн-чат и секреты вне БД
- ADR-019: HTTP/SSE-транспорт через `ApiClient`, 3 попытки всего, retry только
  до потока
- ADR-020: единый контракт LLM, streaming, privacy guard через `LlmContextRef`
  и границы tools/RAG

## Активный агент
- agent-1: DeepSeek V4.1 Flash Free (OpenCode), ветка master
- agent-2: ревью stage-00 — **PASS WITH COMMENTS**; ревью stage-02 —
  **FAIL** (2 MAJOR, 6 MINOR); повторное ревью №2 (2026-10-24) — **FAIL**
  (1 MAJOR R02-009, 2 MINOR, 2 NIT); повторное ревью №3 (2026-10-24) —
  **PASS WITH COMMENTS** (0 MAJOR, 1 MINOR R02-014, 1 NIT R02-015);
  независимое ревью stage-03 (reviewer A, 2026-10-25) — **FAIL**
  (2 MAJOR, 9 MINOR, 6 NIT); исправления S03 — agent-1 (`14e63a7`);
  повторное независимое ревью ещё не проводилось; ревью stage-01 не
  проводилось.
- agent-3: независимое ревью stage-03 (reviewer B, 2026-10-25) — **FAIL**
  (2 MAJOR, 13 MINOR, 4 NIT). Повторный вердикт по исправлениям ожидается от
  нового независимого прохода.

## Ссылки
- Отчёт stage-03: [stages/stage-03.md](stages/stage-03.md)
- Ревью stage-03: [reviews/stage-03-review.md](reviews/stage-03-review.md)
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
  исправлений — следующий коммит.
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
