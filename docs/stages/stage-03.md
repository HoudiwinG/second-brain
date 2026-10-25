# Stage-03 — LLM-слой

- **Дата:** 2026-10-24
- **Агент:** agent-1 (DeepSeek V4.1 Flash Free, OpenCode)
- **Ветка:** `master`
- **Коммит:** `0ae0c85` — код и тесты; документация этапа — отдельный коммит
- **Статус:** **self-check done; независимое ревью — FAIL (2026-10-25)**.
  Открыты 3 MAJOR, stage-04 заблокирован до исправления и повторного ревью.
  Локально: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **104/104**, `flutter build windows --debug` — success. CI-run
  [40112234645](https://github.com/HoudiwinG/second-brain/actions/runs/40112234645)
  (`0ae0c85`) — `analyze-and-test` и `build-windows` **success**.
- **Ревью:** [reviews/stage-03-review.md](../reviews/stage-03-review.md) —
  два независимых прохода, **FAIL**: reviewer A — 2 MAJOR/9 MINOR/6 NIT,
  reviewer B — 2 MAJOR/13 MINOR/4 NIT; после объединения дублей — 3 MAJOR,
  17 MINOR, 8 NIT.
- **Следующий этап:** исправить S03-001…S03-003, повторно пройти ревью, затем
  stage-04 (инструменты ассистента) по `PROMPT.md`.

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
- `sendStreamed` — запрос с `connectTimeout` 15 с и максимум 3 попытками;
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
- финальный `done`-чанк всегда отдаётся после завершения потока и содержит
  накопленный usage. Для Anthropic usage из `message_start` и
  `message_delta` объединяется, а не перезаписывается;
- tool-call-дельты собираются в `LlmResponse.toolCalls`; выполнения
  инструментов на этом этапе нет.

Поддерживаемые типы и значения по умолчанию (`LlmProviderType`):

| Тип | Base URL | Модель по умолчанию |
|-----|----------|---------------------|
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| OpenAI-compatible | `http://localhost:11434/v1` | `llama3.1` |
| Anthropic | `https://api.anthropic.com/v1` | `claude-3-5-sonnet-latest` |
| Google | `https://generativelanguage.googleapis.com/v1beta` | `gemini-2.0-flash` |

### Конфигурации и ключи

`lib/data/repositories/llm_config_repository.dart`:

- CRUD конфигураций, выбор провайдера по умолчанию, чтение/запись/удаление
  ключа;
- API-ключ пишется только в `SecretStore`; в БД хранится уникальный
  `secretRef` вида `llm.api_key.<random>`;
- при создании первой конфигурации она автоматически становится default;
- при ошибке записи конфигурации после сохранения ключа выполняется
  компенсирующее удаление/восстановление ключа;
- удаление конфигурации ставит `provider_config_id = NULL` у тредов, история
  чата сохраняется;
- валидация: `baseUrl` — только HTTP/HTTPS, имя/модель не пустые,
  `maxTokens` — 1…32768, по умолчанию 1024.

`lib/features/llm/application/llm_config_controller.dart` и
`lib/features/llm/presentation/llm_settings_section.dart`:

- список провайдеров, добавление/редактирование/удаление, выбор default;
- поля имени, типа, base URL, модели, ключа и лимита токенов;
- ключ можно не менять при редактировании; пустая строка удаляет его;
- сохранение и удаление показывают локализованные SnackBar;
- индикатор «ключ сохранён» строится по наличию секрета, сам ключ в UI
  повторно не показывается.

### Чат

`lib/features/chat/application/chat_controller.dart`:

- загрузка тредов и сообщений из БД при старте; история доступна офлайн;
- новый тред, выбор треда, удаление, отправка сообщения;
- перед запросом читается ключ, формируется `LlmChatRequest` с моделью треда,
  лимитом токенов провайдера и определениями tools из реестра;
- streaming обновляет `streamingText`; завершённый ответ сохраняется в БД
  вместе с usage;
- отмена останавливает подписку, сохраняет уже полученный фрагмент; пустой
  ответ сохраняется как маркер `cancelled`;
- ошибка провайдера сохраняется как маркер `llm_error` без тела ответа;
- сообщения с ошибкой/отменой не содержат приватного текста;
- `ChatController` не пересоздаётся при каждом изменении настроек. При
  создании треда фиксируются `provider_config_id` и модель; актуальные
  base URL, ключ и `maxTokens` читаются при отправке. Если конфигурация
  удалена, используется default-провайдер, а модель остаётся снимком треда.

`lib/features/chat/presentation/chat_screen.dart`:

- список тредов, кнопка нового чата и удаления;
- лента сообщений, индикатор streaming и кнопка остановки;
- пустое состояние с переходом в настройки, если провайдер не настроен;
- локализованные ошибки: нет конфигурации, провайдер удалён, ошибка LLM,
  ответ остановлен.

### Privacy guard

`lib/features/llm/application/privacy_guard.dart`:

- `LlmContextItem` описывает сущность, которую можно передать в LLM;
- `PrivacyGuard.filter` исключает все элементы с `isPrivateForLlm = true`;
- логируется только количество и типы отфильтрованных сущностей, без
  заголовков и содержимого;
- фильтрация вызывается в `ChatController.sendMessage(context: ...)` до
  формирования текста запроса.

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
- `ChatController`, `ChatState`.
- `PrivacyGuard`, `LlmContextItem`, `PrivacyFilterResult`.
- `LlmTool`, `LlmToolRegistry`, `EmbeddingService`, `VectorStore`.
- DI: `chatRepositoryProvider`, `llmConfigRepositoryProvider`,
  `llmProviderFactoryProvider`, `llmToolRegistryProvider`,
  `llmConfigControllerProvider`, `chatControllerProvider`.

## Схема БД на конец этапа

`schemaVersion = 4`. Новые таблицы:

| Таблица | Поля |
|---------|------|
| `llm_provider_configs` | `id`, `provider_type`, `display_name`, `base_url`, `model`, `max_tokens` (default 1024), `secret_ref` (unique), `is_default`, `created_at`, `updated_at` |
| `chat_threads` | `id`, `title`, `provider_config_id` (nullable, FK → `llm_provider_configs` ON DELETE SET NULL), `model`, `created_at`, `updated_at`, `archived_at` |
| `chat_messages` | `id`, `thread_id` (FK → `chat_threads` ON DELETE CASCADE), `role`, `content`, `prompt_tokens`, `completion_tokens`, `error_code`, `created_at` |

Индексы: `idx_llm_configs_default`, `idx_chat_threads_updated`,
`idx_chat_messages_thread`.

Миграции:

- `v3 → v4` — создание трёх таблиц и индексов;
- `v1 → v4` — создание ядра, FTS5, напоминаний и LLM-таблиц; индексы
  создаются после всех таблиц, чтобы порядок `v1 → v4` не зависел от веток;
- guard `from > to || from > 4 || to > 4` стоит до DDL; downgrade и
  неподдерживаемые переходы не оставляют частичную миграцию;
- `onCreate` создаёт схему v4 и индексы, FTS5 — отдельными SQL-командами
  (ADR-013, ADR-018).

## Зависимости, добавленные на этапе

- `http: ^1.6.0` — HTTP и SSE-транспорт под `ApiClient`.
- Новых платформенных плагинов нет; secure storage уже был на stage-00.

## Тесты

Локально (Flutter 3.47.7, Dart 3.13.5):

```powershell
flutter pub get --enforce-lockfile   # OK
flutter gen-l10n                     # OK
flutter analyze --fatal-infos        # 0 issues
flutter test                         # 104/104
flutter build windows --debug        # success
```

Новые тесты:

- `test/llm_provider_test.dart` — OpenAI streaming/usage/tool calls,
  retry только до SSE, отсутствие retry на 401, embeddings; Anthropic
  streaming/usage/заголовки; Google streaming/usage/URL/заголовок;
- `test/privacy_guard_test.dart` — фильтрация приватных сущностей, типы и
  количество, пустой контекст;
- `test/llm_repositories_test.dart` — ключ только в SecretStore, default,
  обновление/удаление ключа, валидация, удаление конфигурации не удаляет
  историю, CRUD тредов и каскад сообщений;
- `test/chat_controller_test.dart` — streaming и сохранение usage, лимит
  токенов в запросе, отсутствие приватного контекста в теле запроса,
  отмена с сохранением фрагмента, ошибка провайдера, восстановление истории
  без сети;
- `test/llm_settings_widget_test.dart` — отображение конфигурации и сохранение
  нового провайдера через диалог;
- `test/chat_screen_widget_test.dart` — пустой чат без провайдера и переход
  к настройкам;
- `test/db_migration_test.dart` (обновлён) — схема v4, `v3 → v4`, `v1 → v4`,
  future-version и downgrade guard.

Не покрыто автоматическими тестами:

- реальный сетевой запрос к OpenAI/Anthropic/Google с настоящим ключом
  (все адаптеры проверены через `MockClient`);
- ручной GUI-сценарий с реальным провайдером и streaming в Windows;
- выполнение tools и RAG-индексация (вне stage-03);
- визуальные/golden-проверки (TD-18).

## Известные ограничения и техдолг

- Чат пока не умеет прикреплять контекст из заметок/задач через UI: privacy
  guard реализован и вызывается через `sendMessage(context:)`, но экран чата
  не содержит выбора сущностей. Это задача stage-04 вместе с tools — TD-28.
- Tool calls парсятся и сохраняются в `LlmResponse`, но не выполняются;
  реестр инструментов пуст до stage-04.
- RAG-интерфейсы не реализованы: нет индексации, векторного хранилища и
  использования embeddings в поиске.
- Модель вводится вручную; автоматического получения списка моделей от
  провайдера нет.
- Retry после начала SSE-потока не выполняется: частичный ответ сохраняется,
  повторный запрос должен инициировать пользователь.
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
   `secret_ref`.
7. При наличии реального ключа — повторить п. 3–5 на живом API.

## Ссылки

- [ADR-018](../decisions.md) — схема v4 и секреты LLM
- [ADR-019](../decisions.md) — HTTP/SSE-транспорт
- [ADR-020](../decisions.md) — контракт провайдеров, streaming, tools и RAG
- [Техдолг](../tech-debt.md)
- [Контекст](../context.md)
- [Индекс](../INDEX.md)
