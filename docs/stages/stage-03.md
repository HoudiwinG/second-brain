# Stage-03 — LLM-слой

- **Дата:** 2026-10-24; исправления ревью — 2026-10-28
- **Агент:** agent-1 (DeepSeek V4.1 Flash Free, OpenCode)
- **Ветка:** `master`
- **Коммит:** `0ae0c85` — базовая реализация; `14e63a7` — исправления
  S03-001…S03-028; документация исправлений — `49bc00f`, `3089b79`;
  повторное ревью — отдельный коммит после `3089b79`.
- **Статус:** **done; повторное независимое ревью — PASS (2026-10-28)**.
  Исходное независимое ревью **FAIL** (2026-10-25) сохранено в истории, но
  все 28 находок подтверждены как закрытые (28/28 verified). Stage-04
  **разблокирован**. Локально после исправлений: `flutter analyze
  --fatal-infos` — **No issues found**, `flutter test` — **132/132**,
  `flutter build windows --debug` — **success**
  (`build\windows\x64\runner\Debug\second_brain.exe`). CI-run
  [40636764573](https://github.com/HoudiwinG/second-brain/actions/runs/40636764573)
  (`49bc00f`, включающий `14e63a7`) — `analyze-and-test` и `build-windows`
  **success**.
- **Ревью:** исходное — [reviews/stage-03-review.md](../reviews/stage-03-review.md),
  два независимых прохода, **FAIL**: reviewer A — 2 MAJOR/9 MINOR/6 NIT,
  reviewer B — 2 MAJOR/13 MINOR/4 NIT; после объединения дублей — 3 MAJOR,
  17 MINOR, 8 NIT. **Формальный вердикт не изменён.**
- **Повторное ревью:** [reviews/stage-03-repeat-review.md](../reviews/stage-03-repeat-review.md)
  — **PASS**, 28/28 verified, 0 CRITICAL/0 MAJOR, 2 MINOR (S03R-001/S03R-002)
  и 2 NIT (S03R-003/S03R-004).
- **Результаты исправлений:** [reviews/stage-03-fix-results.md](../reviews/stage-03-fix-results.md)
  — доказательства по каждому S03-ID.
- **Следующий этап:** stage-04 (инструменты ассистента) по `PROMPT.md`;
  S03R-001…S03R-004 учитываются как неблокирующие комментарии.

## Итог независимого ревью (2026-10-25)

Два независимых агента (reviewer A и reviewer B) провели полное ревью кода,
схемы, тестов и документации. Оба вердикта — **FAIL**. Блокеры:

1. **S03-001** — после любой ошибки провайдера `errorCode = 'llm_error'`
   блокирует повторную отправку в текущем треде; ввод теряется.
2. **S03-002** — обрезка истории не выравнивает роли: длинный тред может
   отправить запрос, начинающийся с `assistant`, и получить 400 от
   Anthropic/Google.
3. **S03-003** — создание нового треда во время streaming оставляет старый
   поток активным; завершение подменяет сообщения нового треда.

Дополнительно найдены 17 MINOR и 8 NIT, в том числе: удаление ключа и
индикатор «ключ сохранён» не реализованы в UI; embeddings используют
chat-модель; `http://` разрешён для удалённых хостов; порядок сообщений без
tie-breaker; partial-ответ при ошибке сохраняется без маркера; retry-политика
расходится с ADR-019; часть критичных переходов состояния не покрыта тестами.
Полный список с доказательствами — в
[reviews/stage-03-review.md](../reviews/stage-03-review.md).

## Исправления по ревью (2026-10-28)

Все 28 находок S03-001…S03-028 исправлены коммитом `14e63a7`; подробные
доказательства и тесты — в
[reviews/stage-03-fix-results.md](../reviews/stage-03-fix-results.md).
Ключевые изменения:

- чат получил `Future<bool> sendMessage`, `requestId`, синхронный guard,
  отмену при смене/создании/удалении треда и `retryLast`; partial-ответ с
  ошибкой сохраняется с маркером `llm_error` (S03-001/003/013/018);
- история запроса вынесена в `buildChatRequestMessages`: лимиты 40 сообщений и
  60 000 символов, выравнивание ролей, склейка одинаковых ролей, фильтрация
  приватных и ошибочных сообщений (S03-002/007/027);
- приватность контекста теперь читается из БД через `LlmContextRef` +
  `DriftLlmContextLoader`; у сообщений есть собственный флаг приватности
  (S03-006/007);
- схема БД — **v5**: `embedding_model`, `is_private_for_llm`, partial unique
  index для единственного default и миграция v4→v5 (S03-004/014);
- настройки получили отдельную embedding-модель, явное удаление ключа,
  inline-валидацию и индикатор наличия ключа (S03-005/010/014);
- сеть и секреты: HTTPS для не-loopback, компенсация/восстановление ключей,
  безопасные логи, fallback модели при удалении провайдера
  (S03-008/009/015/017);
- OpenAI-compatible повторяет запрос без `stream_options` при 400/422;
  retry-политика в ADR и коде согласована (S03-020/025);
- добавлены локализованные подписи и кнопка повтора; «Open settings»
  показывается только для ошибок конфигурации (S03-023/028).

## Повторное независимое ревью (2026-10-28)

Независимый ревьюер (Gemini 4 Argon) проверил `master` @ `3089b79`, код
исправлений `14e63a7` и документацию `49bc00f`/`3089b79`. Локальные гейты
воспроизведены: analyze — 0 issues, test — 132/132, Windows debug build —
success; CI-run `40636764573` и `40637438577` — success.

- **Вердикт: PASS.** Все 28 исходных находок `S03-001`…`S03-028` подтверждены
  (28/28 verified).
- Новых блокеров нет: 0 CRITICAL, 0 MAJOR.
- Неблокирующие замечания: S03R-001/S03R-002 (MINOR), S03R-003/S03R-004 (NIT);
  они относятся к stage-04 и не отменяют PASS.
- **Stage-04 разблокирован.** Исходный FAIL в `stage-03-review.md` остаётся
  историческим артефактом и не переписывается.

## Цель этапа

Подключить реальный LLM-слой: несколько провайдеров, безопасное хранение
API-ключей, потоковый чат с отменой и лимитами, офлайн-история, privacy guard,
контракт tools и интерфейсы RAG.

Критерии приёмки stage-03:

- OpenAI-совместимый, Anthropic и Google-провайдеры реализуют единый контракт
  chat/streaming/tools/embeddings;
- API-ключи хранятся только в secure storage, в БД и логах их нет;
- провайдер и модель переключаются в настройках; несколько конфигураций,
  провайдер по умолчанию и лимит токенов;
- чат стримит ответ, умеет отменять запрос и сохраняет историю локально;
- перед отправкой контекста приватные для LLM сущности отфильтровываются,
  в лог попадают только количество и типы;
- есть реестр инструментов и интерфейсы embeddings/VectorStore;
- `flutter analyze --fatal-infos`, `flutter test` и
  `flutter build windows --debug` проходят локально.

Вне stage-03: реальное выполнение tools и аудит действий (stage-04), почта
(stage-06), индексация RAG и обучение (следующие этапы).

## Что реализовано

### Сеть и SSE

`lib/core/network/api_client.dart`:

- реальный HTTP-транспорт поверх `http 1.6.0`; единая точка для таймаутов,
  retry и логирования;
- `sendStreamed` — запрос с `connectTimeout` 15 с; `maxRetries = 3` означает
  **3 попытки всего** (первая + два повтора), паузы между ними — 200 и 400 мс;
- retry только для `408`, `425`, `429`, `5xx`, таймаутов и сетевых ошибок и
  **только до получения успешного ответа**. После начала SSE-потока повтор
  запрещён, чтобы не дублировать текст в UI (ADR-019);
- `requestJson` — сборка и разбор JSON, ошибки чтения/формата;
- `streamLines` — построчное чтение SSE через `LineSplitter` и
  `receiveTimeout` 60 с;
- тело HTTP-ошибки вычитывается и не логируется; в сообщениях только статус,
  метод и путь, без ключей и содержимого пользователя.

### Провайдеры LLM

`lib/features/llm/`:

- `LlmProvider` — общий контракт `streamChat` / `complete` / `embed`;
- `LlmChunk` — приращение текста, флаг завершения, usage и tool-call-дельты;
- `LlmUsage` — prompt/completion/total tokens с объединением частичных данных;
- `OpenAiCompatibleProvider` — `/chat/completions` и `/embeddings`, подходит
  для OpenAI и локальных/российских OpenAI-совместимых API;
- `AnthropicProvider` — `/messages`, заголовки `x-api-key` и
  `anthropic-version`, system-сообщения выносятся в отдельное поле;
- `GoogleProvider` — `:streamGenerateContent?alt=sse` и `:embedContent`,
  `systemInstruction`, `generationConfig.maxOutputTokens`;
- единый `LlmProviderFactory` создаёт адаптер по сохранённой конфигурации и
  переиспользует один HTTP-клиент;
- финальный `done`-чанк отдаётся после завершения потока и содержит
  накопленный usage, **если провайдер его вернул**; иначе `usage == null`.
  Для Anthropic usage из `message_start` и `message_delta` объединяется, а не
  перезаписывается;
- embeddings используют отдельную `embeddingModel`: явное значение
  конфигурации, затем провайдерский default (`text-embedding-3-small`,
  `nomic-embed-text`, `text-embedding-004`); Anthropic embeddings не
  поддерживает;
- OpenAI-compatible при HTTP 400/422 повторяет запрос без `stream_options`:
  старые Ollama/vLLM не знают это поле;
- tool-call-дельты собираются в `LlmResponse.toolCalls`; выполнения
  инструментов на этом этапе нет.

Поддерживаемые типы и значения по умолчанию (`LlmProviderType`):

| Тип | Base URL | Чат-модель | Embedding-модель |
|-----|----------|------------|------------------|
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` | `text-embedding-3-small` |
| OpenAI-compatible | `http://localhost:11434/v1` | `llama3.1` | `nomic-embed-text` |
| Anthropic | `https://api.anthropic.com/v1` | `claude-3-5-sonnet-latest` | — |
| Google | `https://generativelanguage.googleapis.com/v1beta` | `gemini-2.0-flash` | `text-embedding-004` |

### Конфигурации и ключи

`lib/data/repositories/llm_config_repository.dart`:

- CRUD конфигураций, выбор провайдера по умолчанию, чтение/запись/удаление
  ключа;
- API-ключ пишется только в `SecretStore`; в БД хранится уникальный
  `secretRef` вида `llm.api_key.<random>`;
- инвариант «ровно один default, если есть конфигурации» поддерживается при
  create/update/delete/setDefault; на уровне БД его защищает partial unique
  index `idx_llm_configs_default ... WHERE is_default = 1`;
- при создании первой конфигурации она автоматически становится default;
- при ошибке записи конфигурации после сохранения ключа выполняется
  компенсирующее удаление/восстановление ключа;
- удаление конфигурации ставит `provider_config_id = NULL` у тредов, история
  чата сохраняется;
- валидация: `baseUrl` — `https` для удалённых хостов и `http` только для
  loopback (`localhost`, `127.0.0.1`, `::1`); имя/модель не пустые,
  `maxTokens` — 1…32768, по умолчанию 1024.

`lib/features/llm/application/llm_config_controller.dart` и
`lib/features/llm/presentation/llm_settings_section.dart`:

- список провайдеров, добавление/редактирование/удаление, выбор default;
- поля имени, типа, base URL, чат-модели, embedding-модели, ключа и лимита
  токенов;
- ключ можно не менять при редактировании; явная кнопка «Удалить сохранённый
  ключ» удаляет его, пустое поле означает «не менять»;
- форма валидирует обязательные поля, `maxTokens` и base URL до сохранения;
  при ошибке диалог остаётся открытым и ввод не теряется;
- сохранение и удаление показывают локализованные SnackBar;
- индикатор «ключ сохранён»/«ключ не задан» строится по наличию секрета, сам
  ключ в UI повторно не показывается.

### Чат

`lib/features/chat/application/chat_controller.dart`:

- загрузка тредов и сообщений из БД при старте; история доступна офлайн;
- новый тред, выбор треда, удаление, отправка сообщения, `retryLast`;
- `sendMessage` возвращает `Future<bool>`: UI очищает ввод только после
  подтверждения приёма; старый `llm_error` не блокирует следующую отправку;
- синхронный `_sending` guard не пропускает параллельные отправки; у запроса
  есть `requestId`, а callbacks проверяют активный тред. Создание, выбор и
  удаление активного треда во время streaming сначала отменяют запрос и
  сохраняют partial-ответ;
- перед запросом читается ключ; отсутствие ключа для провайдера, которому он
  нужен, даёт `api_key_missing` без сетевого вызова;
- история запроса строится `buildChatRequestMessages`: последние 40 сообщений,
  не более 60 000 символов с учётом контекста, без ведущих `assistant`,
  с склейкой подряд идущих одинаковых ролей и без приватных/ошибочных
  сообщений;
- streaming обновляет `streamingText`; завершённый ответ сохраняется в БД
  вместе с usage;
- отмена останавливает подписку, сохраняет уже полученный фрагмент; пустой
  ответ сохраняется как маркер `cancelled`;
- ошибка провайдера сохраняется как маркер `llm_error` без тела ответа;
  partial-ответ при ошибке тоже получает `error_code = 'llm_error'` и не
  попадает в следующий запрос;
- `ChatController` не пересоздаётся при каждом изменении настроек. При
  создании треда фиксируются `provider_config_id` и модель; актуальные
  base URL, ключ и `maxTokens` читаются при отправке. Если конфигурация
  удалена, используется default-провайдер **и его модель**.

`lib/features/chat/presentation/chat_screen.dart`:

- список тредов, кнопка нового чата и удаления;
- лента сообщений, индикатор streaming и кнопка остановки;
- офлайн-история видна даже без провайдера; отключается только composer;
- сообщение можно пометить как приватное для будущих LLM-запросов;
- для `llm_error` показывается «Повторить», для ошибок конфигурации —
  «Open settings»; для `cancelled` — только локализованное сообщение.

### Privacy guard

`lib/features/llm/application/privacy_guard.dart` и
`lib/features/llm/application/llm_context_loader.dart`:

- `LlmContextItem` описывает сущность, которую можно передать в LLM;
- вызывающий код передаёт только `LlmContextRef(type, id)`; содержимое и флаг
  `isPrivateForLlm` читает `DriftLlmContextLoader` из БД, поэтому подделать
  приватность из UI нельзя;
- `PrivacyGuard.filter` исключает все элементы с `isPrivateForLlm = true`;
- логируется только количество и типы отфильтрованных сущностей, без
  заголовков и содержимого;
- фильтрация вызывается в `ChatController.sendMessage(contextRefs: ...)` до
  формирования текста запроса; у сохранённых сообщений чата есть отдельный
  флаг `isPrivateForLlm`, который также исключает их из следующих запросов.

### Tools и RAG — каркас

- `lib/features/llm/tools/llm_tool_registry.dart` — контракт `LlmTool`,
  реестр с защитой от пустых/дублирующихся имён и `definitions`;
- `lib/features/llm/domain/llm_tool.dart` — сериализация определений и
  tool-call-дельт для OpenAI/Anthropic/Google;
- `lib/features/llm/rag/embedding_service.dart` — `EmbeddingService`
  (`embed`, `embedBatch`);
- `lib/features/llm/rag/vector_store.dart` — `VectorRecord`,
  `VectorSearchHit`, `VectorStore` (`upsert`, `delete`, `search`);
- реестр на stage-03 пуст и передаётся в запрос как пустой список; RAG-сервисы
  не подключены к индексации.

## Контракты и интерфейсы

- `ApiClient` — `sendStreamed`, `requestJson`, `streamLines`, `buildUrl`,
  `defaultHeaders`, `close`.
- `LlmProvider` — `streamChat`, `complete`, `embed`.
- `LlmChatRequest`, `LlmChunk`, `LlmUsage`, `LlmResponse`.
- `LlmProviderType`, `LlmProviderConfig`, `LlmConfigDraft`.
- `LlmConfigRepository` + `DriftLlmConfigRepository`.
- `ChatRepository` + `DriftChatRepository`.
- `ChatController`, `ChatState`; `sendMessage` → `Future<bool>`, `retryLast`,
  `waitForIdle`.
- `PrivacyGuard`, `LlmContextItem`, `PrivacyFilterResult`, `LlmContextRef`,
  `LlmContextLoader` + `DriftLlmContextLoader`.
- `buildChatRequestMessages` (`chat_request_builder.dart`).
- `LlmTool`, `LlmToolRegistry`, `EmbeddingService`, `VectorStore`.
- `LlmEndpoint` — проверка base URL и необходимости API-ключа.
- DI: `chatRepositoryProvider`, `llmConfigRepositoryProvider`,
  `llmContextLoaderProvider`, `llmProviderFactoryProvider`,
  `llmToolRegistryProvider`, `llmConfigControllerProvider`,
  `chatControllerProvider`.

## Схема БД на конец этапа

`schemaVersion = 5`. Таблицы LLM-слоя:

| Таблица | Поля |
|---------|------|
| `llm_provider_configs` | `id`, `provider_type`, `display_name`, `base_url`, `model`, `embedding_model` (nullable), `max_tokens` (default 1024), `secret_ref` (unique), `is_default`, `created_at`, `updated_at` |
| `chat_threads` | `id`, `title`, `provider_config_id` (nullable, FK → `llm_provider_configs` ON DELETE SET NULL), `model`, `created_at`, `updated_at`, `archived_at` |
| `chat_messages` | `id`, `thread_id` (FK → `chat_threads` ON DELETE CASCADE), `role`, `content`, `prompt_tokens`, `completion_tokens`, `error_code`, `is_private_for_llm` (default false), `created_at` |

Индексы: `idx_llm_configs_default` (partial unique,
`WHERE is_default = 1`), `idx_chat_threads_updated`,
`idx_chat_messages_thread` (`thread_id, created_at, id`).

Миграции:

- `v3 → v4` — создание трёх LLM-таблиц;
- `v4 → v5` — добавление `embedding_model` и `is_private_for_llm`,
  нормализация default-конфигураций и замена индекса на partial unique;
- `v1 → v5` / `v2 → v5` — создание ядра, FTS5, напоминаний и LLM-таблиц
  текущей структуры; индексы создаются после всех таблиц;
- guard `from > to || from > 5 || to > 5` стоит до DDL; downgrade и
  неподдерживаемые переходы не оставляют частичную миграцию;
- `onCreate` создаёт схему v5 и индексы, FTS5 — отдельными SQL-командами
  (ADR-013, ADR-018).

Partial-ответ при ошибке сохраняется с `error_code = 'llm_error'`; это
защищает следующий запрос от попадания неполного ответа в историю (S03-018).


## Зависимости, добавленные на этапе

- `http: ^1.6.0` — HTTP и SSE-транспорт под `ApiClient`.
- Новых платформенных плагинов нет; secure storage уже был на stage-00.

## Тесты

Локально (Flutter 3.47.7, Dart 3.13.5):

```powershell
flutter pub get --enforce-lockfile   # OK
flutter gen-l10n                     # OK
flutter analyze --fatal-infos        # No issues found
flutter test                         # 132/132
flutter build windows --debug        # success
```

Новые/обновлённые тесты:

- `test/llm_provider_test.dart` — OpenAI streaming/usage/tool calls,
  retry только до SSE, отсутствие retry на 401, embeddings, отдельная
  embedding-модель, fallback без `stream_options`; Anthropic
  streaming/usage/заголовки; Google streaming/usage/URL/заголовок;
- `test/llm_safety_test.dart` — безопасный `toString`, trim имени инструмента,
  `http` только для loopback;
- `test/privacy_guard_test.dart` — фильтрация приватных сущностей, типы и
  количество, пустой контекст;
- `test/llm_repositories_test.dart` — ключ только в SecretStore, инвариант
  default и partial unique index, update/удаление ключа, валидация HTTPS,
  компенсация секретов, удаление конфигурации не удаляет историю, CRUD тредов,
  приватность и порядок сообщений;
- `test/chat_request_builder_test.dart` — лимиты 40/60 000, выравнивание ролей,
  склейка, приватные и ошибочные сообщения, размещение контекста;
- `test/chat_controller_test.dart` — streaming и usage, приватность из БД,
  отмена, повтор после `llm_error`, `retryLast`, double-send, создание треда
  во время streaming, fallback-модель, отсутствие ключа, офлайн-история;
- `test/llm_settings_widget_test.dart` — отображение конфигурации, сохранение,
  валидация `maxTokens`, удаление ключа без потери ввода;
- `test/chat_screen_widget_test.dart` — офлайн-история без провайдера и
  фактический переход «Open settings» → `/settings`;
- `test/db_migration_test.dart` — схема v5, `v1/v2/v3 → v5`, `v4 → v5`
  (embedding-модель, privacy-флаг, нормализация default), future-version и
  downgrade guard.

Не покрыто автоматическими тестами:

- реальный сетевой запрос к OpenAI/Anthropic/Google с настоящим ключом
  (все адаптеры проверены через `MockClient`);
- ручной GUI-сценарий с реальным провайдером и streaming в Windows;
- выполнение tools и RAG-индексация (вне stage-03);
- визуальные/golden-проверки (TD-18).

## Известные ограничения и техдолг

- Чат пока не умеет прикреплять контекст из заметок/задач/идей через UI:
  privacy guard реализован, production-путь `sendMessage(contextRefs:)` читает
  флаги из БД, но экран чата не содержит выбора сущностей. Это задача stage-04
  вместе с tools — TD-28.
- Tool calls парсятся и сохраняются в `LlmResponse`, но не выполняются;
  реестр инструментов пуст до stage-04.
- RAG-интерфейсы не реализованы: нет индексации, векторного хранилища и
  использования embeddings в поиске.
- Модель вводится вручную; автоматического получения списка моделей от
  провайдера нет.
- Retry после начала SSE-потока не выполняется: частичный ответ сохраняется с
  маркером ошибки, повтор инициирует пользователь кнопкой «Повторить».
- Anthropic не поддерживает embeddings; для RAG нужен OpenAI-compatible или
  Google.
- UI не показывает стоимость запроса; сохраняются только токены.
- Нет редактирования/повторной генерации сообщений, rename треда из UI и
  поиска по истории.
- История чата хранится в локальной БД в открытом виде, как и остальные
  данные приложения; шифрование полей через `CryptoService` — отдельный этап.
- Реальный сетевой smoke с ключом не выполнялся; это остаётся в чек-листе
  ревьюера/пользователя.

## Как запустить и проверить этап

```powershell
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze --fatal-infos
flutter test
flutter build windows --debug
.\build\windows\x64\runner\Debug\second_brain.exe
```

Ручной чек-лист:

1. Открыть «Настройки» → «LLM-провайдеры», добавить провайдера, ввести
   base URL, модель, ключ и лимит токенов.
2. Сохранить, перезапустить приложение и убедиться, что конфигурация и
   индикатор сохранённого ключа остались.
3. Открыть «Чат», отправить сообщение и увидеть постепенный streaming;
   нажать «Остановить» — текст должен остановиться, частичный ответ
   сохраниться.
4. Перезапустить приложение и открыть чат: история и сообщения должны
   загрузиться без сети.
5. Переключить default-провайдера и создать новый тред; запрос должен уйти
   с моделью и лимитом нового провайдера.
6. Проверить, что ключ не отображается в БД и логах; в БД есть только
   `secret_ref`. Удалить ключ через диалог редактирования и убедиться, что
   индикатор сменился на «ключ не задан».
7. При ошибке провайдера нажать «Повторить» и убедиться, что запрос уходит
   повторно; пометить сообщение приватным и проверить, что оно не попадает
   в следующий запрос.
8. При наличии реального ключа — повторить п. 3–5 на живом API.

## Ссылки

- [Результаты исправлений S03](../reviews/stage-03-fix-results.md)
- [ADR-018](../decisions.md) — схема v5 и секреты LLM
- [ADR-019](../decisions.md) — HTTP/SSE-транспорт
- [ADR-020](../decisions.md) — контракт провайдеров, streaming, tools и RAG
- [Техдолг](../tech-debt.md)
- [Контекст](../context.md)
- [Индекс](../INDEX.md)
