# Stage-03 — результаты исправлений S03-001…S03-028

- **Дата (UTC):** 2026-10-28
- **Автор:** agent-1 (DeepSeek V4.1 Flash Free, OpenCode)
- **Источник находок:** [stage-03-review.md](stage-03-review.md) — независимое
  ревью двумя агентами, вердикт **FAIL** (critical 0, major 3, minor 17, nit 8).
- **Проверяемое состояние:** `master` @ `14e63a7` (код и тесты исправлений);
  документация — отдельный коммит после `14e63a7`.
- **Характер документа:** self-check разработчика и доказательства. Это **не
  вердикт ревью**. Исходный вердикт **FAIL** в `stage-03-review.md` сохранён без
  изменений. Повторное независимое ревью —
  [stage-03-repeat-review.md](stage-03-repeat-review.md): **PASS**, 28/28
  verified; stage-04 разблокирован.

## Сводка

Все 28 находок закрыты в коде и тестах. Открытых S03-находок в этом проходе не
осталось; новых TD не заводилось. TD-28 (UI выбора контекста) остаётся
осознанно принятым ограничением и не дублирует исправление S03-006.

| ID | Severity | Статус | Краткое доказательство |
|----|----------|--------|------------------------|
| S03-001 | MAJOR | fixed | `sendMessage → Future<bool>`, нет глобального блока по `llm_error`; тест повторной отправки |
| S03-002 | MAJOR | fixed | `buildChatRequestMessages`: выравнивание ролей, склейка, лимиты; 6 unit-тестов |
| S03-003 | MAJOR | fixed | `requestId`, отмена при create/select/delete, проверка активного треда; тест |
| S03-004 | MINOR | fixed | инвариант «ровно один default» + partial unique index + миграционная нормализация |
| S03-005 | MINOR | fixed | индикатор «ключ сохранён», явное удаление ключа, сохранение без потери ввода |
| S03-006 | MINOR | fixed | `LlmContextRef` + `DriftLlmContextLoader`; флаг приватности читается из БД |
| S03-007 | MINOR | fixed | `chat_messages.is_private_for_llm` + переключатель в UI + фильтрация в builder |
| S03-008 | MINOR | fixed | компенсация/восстановление секретов с обработкой `Result`; 2 failure-теста |
| S03-009 | MINOR | fixed | при fallback используется модель default-конфигурации; тест |
| S03-010 | MINOR | fixed | inline-валидация формы, диалог не закрывается, `maxTokens` не превращается в 1024 |
| S03-011 | MINOR | fixed | офлайн-история видна без провайдера; отключён только composer; widget-тест |
| S03-012 | MINOR | fixed | regression-тесты на все критичные переходы; `flutter test` — 132/132 |
| S03-013 | MINOR | fixed | синхронный `_sending` guard до первого `await`; тест double-send |
| S03-014 | MINOR | fixed | отдельная `embedding_model`; UI-поле; OpenAI/Google используют её |
| S03-015 | MINOR | fixed | `http` только для loopback, удалённые хосты требуют `https` |
| S03-016 | MINOR | fixed | сортировка `createdAt, id`; `appendMessage` в транзакции с `updatedAt` |
| S03-017 | MINOR | fixed | `AppException.toString` без `cause`; неизвестные ошибки логируются по типу |
| S03-018 | MINOR | fixed | partial-ответ при ошибке сохраняется с `error_code = 'llm_error'` |
| S03-019 | MINOR | fixed | комментарий схемы соответствует сохранению partial-ответа |
| S03-020 | MINOR | fixed | ADR/код: 3 попытки всего, паузы 200/400 мс |
| S03-021 | NIT | fixed | отсутствие ключа определяется до сети → `api_key_missing`; тест |
| S03-022 | NIT | fixed | `definition.name` использует trim-имя; тест |
| S03-023 | NIT | fixed | хардкод `'Chat'` и подпись модели/токенов заменены ARB-ключами |
| S03-024 | NIT | fixed | убраны вводящие в заблуждение `isLocal`/`supportsEmbeddings`, добавлена embedding-модель |
| S03-025 | NIT | fixed | OpenAI-compatible повторяет запрос без `stream_options` при 400/422 |
| S03-026 | NIT | fixed | widget-тест нажимает «Open settings» и проверяет навигацию |
| S03-027 | NIT | fixed | лимит 60 000 символов соблюдается даже одним сообщением |
| S03-028 | NIT | fixed | «Open settings» только для ошибок конфигурации; для `llm_error` — «Повторить» |

## MAJOR

### S03-001 — залипший `llm_error`

- Удалён глобальный ранний выход по `state.errorCode == 'llm_error'`.
- `sendMessage` возвращает `Future<bool>`: `true` — сообщение принято и запрос
  запущен, `false` — ввод не принят. UI очищает поле только после `true`.
- В начале каждой отправки `errorCode` сбрасывается; ошибка чтения ключа
  обрабатывается локально через `keyResult`.
- `retryLast()` повторяет последний запрос без добавления нового user-сообщения;
  ошибки и partial-ответы исключаются из истории.
- **Файлы:** `lib/features/chat/application/chat_controller.dart`,
  `lib/features/chat/presentation/chat_screen.dart`.
- **Тесты:** `test/chat_controller_test.dart` — «ошибка провайдера сохраняет
  маркер и не блокирует отправку», «retryLast повторяет запрос без
  partial-ответа с ошибкой».

### S03-002 — обрезка истории без выравнивания ролей

- Формирование запроса вынесено в `buildChatRequestMessages`.
- Правила: последние 40 сообщений; не более 60 000 символов; фильтрация
  приватных сообщений и error-маркеров; удаление ведущих `assistant`; склейка
  подряд идущих сообщений одной роли; контекст добавляется к последнему
  user-сообщению.
- **Файлы:** `lib/features/chat/application/chat_request_builder.dart`,
  `lib/features/chat/application/chat_controller.dart`.
- **Тесты:** `test/chat_request_builder_test.dart` — 40/41 сообщение, ведущий
  `assistant`, одинаковые роли, приватные/error-сообщения, лимит 60 000,
  размещение и лимит контекста.

### S03-003 — новый тред во время streaming

- `createThread`, `selectThread` и удаление активного треда сначала отменяют
  текущий запрос и сохраняют partial-ответ.
- Каждый запрос получает `requestId`; callbacks и `_refreshMessages` проверяют
  активный `requestId` и `threadId`, поэтому завершение старого потока не
  подменяет сообщения нового треда.
- **Файлы:** `lib/features/chat/application/chat_controller.dart`.
- **Тесты:** `test/chat_controller_test.dart` — «создание нового треда во время
  streaming отменяет старый запрос»; дополнительно проверяется, что поздние
  чанки не попадают в новый тред.

## MINOR

### S03-004 — инвариант «ровно один default»

- `_ensureDefaultExists` вызывается после create/update/delete/setDefault;
  снятие флага назначает другую конфигурацию, а не ту же самую.
- В схеме v5 создан partial unique index
  `idx_llm_configs_default ... WHERE is_default = 1`.
- Миграция v4→v5 нормализует 0/2 default до создания индекса.
- **Файлы:** `lib/data/repositories/llm_config_repository.dart`,
  `lib/data/db/app_database.dart`.
- **Тесты:** `test/llm_repositories_test.dart` — инвариант при
  create/update/delete, partial unique index; `test/db_migration_test.dart` —
  нормализация v4→v5.

### S03-005 — удаление ключа и индикатор наличия

- Карточка провайдера показывает «Ключ сохранён»/«Ключ не задан» по
  `hasApiKey`, сам ключ не отображается.
- В диалоге редактирования есть явная кнопка «Удалить сохранённый ключ»;
  пустое поле означает «не менять», удаление передаёт пустую строку.
- Сохранение/удаление показывают локализованные SnackBar.
- **Файлы:** `lib/features/llm/presentation/llm_settings_section.dart`,
  `lib/data/repositories/llm_config_repository.dart`, ARB RU/EN.
- **Тесты:** `test/llm_settings_widget_test.dart` — «ключ можно удалить, а
  невалидный ввод не теряется»; `test/llm_repositories_test.dart` — update с
  пустой строкой удаляет ключ.

### S03-006 — PrivacyGuard как production-chokepoint

- Вызывающий код передаёт только `LlmContextRef(type, id)`.
- `DriftLlmContextLoader` читает сами сущности и `is_private_for_llm` из БД;
  подделать флаг из UI нельзя.
- `PrivacyGuard.filter` по-прежнему логирует только количество и типы.
- **Файлы:** `lib/features/llm/application/llm_context_loader.dart`,
  `lib/features/chat/application/chat_controller.dart`, `lib/app/di.dart`.
- **Тест:** `test/chat_controller_test.dart` — «приватность контекста читается
  из БД, а не из вызывающего кода».

### S03-007 — признак приватности у сообщений

- В `chat_messages` добавлен `is_private_for_llm` (default false), в домене —
  `ChatMessage.isPrivateForLlm`.
- UI позволяет пометить/снять приватность сохранённого сообщения.
- `buildChatRequestMessages` исключает приватные сообщения из следующих
  запросов.
- **Файлы:** `lib/data/db/app_database.dart`, `lib/features/chat/domain/chat_message.dart`,
  `lib/features/chat/presentation/chat_screen.dart`,
  `lib/features/chat/application/chat_request_builder.dart`.
- **Тесты:** `test/chat_controller_test.dart` — «приватное сообщение не попадает
  в следующий запрос»; `test/llm_repositories_test.dart` — сохранение флага.

### S03-008 — компенсация секретов

- Ошибки записи/чтения/удаления секретов обрабатываются через `Result`.
- При неудачной вставке конфигурации удаляется только что записанный ключ; при
  неудачном обновлении восстанавливается старое значение.
- **Файлы:** `lib/data/repositories/llm_config_repository.dart`.
- **Тесты:** `test/llm_repositories_test.dart` — «ошибка вставки удаляет только
  что записанный секрет», «ошибка обновления восстанавливает старый секрет»
  (через SQLite-триггеры).

### S03-009 — модель при fallback

- `_effectiveModel` возвращает модель default-конфигурации, если исходный
  провайдер треда удалён; снимок модели используется только при совпадении
  `provider_config_id`.
- **Файлы:** `lib/features/chat/application/chat_controller.dart`.
- **Тест:** `test/chat_controller_test.dart` — «fallback на default-провайдера
  использует его модель».

### S03-010 — валидация без потери ввода

- Диалог валидирует обязательные поля, `maxTokens` (1…32768) и base URL до
  сохранения; при ошибке остаётся открытым и сохраняет введённые значения.
- `maxTokens: abc` больше не превращается молча в 1024.
- **Файлы:** `lib/features/llm/presentation/llm_settings_section.dart`.
- **Тест:** `test/llm_settings_widget_test.dart` — «невалидный maxTokens не
  закрывает диалог и не пишет в БД».

### S03-011 — офлайн-история без провайдера

- При пустом списке конфигураций показывается баннер и отключается только
  composer; список тредов и сохранённые сообщения остаются видимыми.
- **Файлы:** `lib/features/chat/presentation/chat_screen.dart`.
- **Тест:** `test/chat_screen_widget_test.dart` — чат без провайдера показывает
  историю и ведёт в настройки.

### S03-012 — покрытие критичных переходов

Добавлены/расширены тесты на: повтор после `llm_error`, `retryLast`, обрезку
истории и ролей, приватность контекста и сообщений, fallback-модель,
компенсацию секретов, double-send, создание треда во время streaming,
отсутствие ключа, сортировку, миграции v3/v4→v5, навигацию и валидацию формы.
Итог: `flutter test` — **132/132**.

### S03-013 — синхронный guard от параллельной отправки

- `_sending = true` выставляется до первого `await`; повторный `sendMessage`
  возвращает `false`, не создавая второй запрос.
- **Файл:** `lib/features/chat/application/chat_controller.dart`.
- **Тест:** `test/chat_controller_test.dart` — «синхронный guard отклоняет
  параллельный sendMessage».

### S03-014 — отдельная embedding-модель

- В `llm_provider_configs` добавлена nullable `embedding_model`; в
  `LlmProviderType` — `defaultEmbeddingModel`.
- OpenAI-compatible и Google используют явную embedding-модель, затем
  провайдерский default; chat-модель больше не подставляется вместо неё.
- В настройках появилось поле «Модель embeddings».
- **Файлы:** `lib/data/db/app_database.dart`,
  `lib/features/llm/domain/llm_provider_type.dart`,
  `lib/features/llm/domain/llm_provider_config.dart`,
  `lib/features/llm/data/openai_compatible_provider.dart`,
  `lib/features/llm/data/google_provider.dart`,
  `lib/features/llm/presentation/llm_settings_section.dart`.
- **Тесты:** `test/llm_provider_test.dart` — обе реализации используют
  `embed-model`/`text-embedding-004`; `test/llm_repositories_test.dart` —
  сохранение `embeddingModel`.

### S03-015 — HTTPS для удалённых хостов

- `LlmEndpoint.isValid` разрешает `http` только для `localhost`, `127.0.0.1`,
  `::1`; остальные хосты требуют `https`.
- Валидация применяется и в репозитории, и в форме настроек.
- **Файлы:** `lib/features/llm/domain/llm_endpoint.dart`,
  `lib/data/repositories/llm_config_repository.dart`.
- **Тесты:** `test/llm_safety_test.dart`, `test/llm_repositories_test.dart`.

### S03-016 — детерминированный порядок и транзакция

- Сообщения сортируются по `createdAt`, затем `id`; индекс включает оба поля.
- `appendMessage` выполняется в транзакции и обновляет `updatedAt` треда.
- **Файлы:** `lib/data/repositories/chat_repository.dart`,
  `lib/data/db/app_database.dart`.
- **Тест:** `test/llm_repositories_test.dart` — «сохраняет приватность сообщения
  и сортирует по createdAt, id».

### S03-017 — безопасное логирование

- `AppException.toString()` печатает только тип и сообщение, без `cause`.
- `AppLogger` для неизвестных ошибок пишет только runtime-тип, чтобы тело
  ответа/JSON не попало в лог.
- **Файлы:** `lib/core/error/app_exception.dart`,
  `lib/core/logging/app_logger.dart`.
- **Тест:** `test/llm_safety_test.dart` — `toString` не содержит тело ответа.

### S03-018 — partial-ответ с ошибкой

- При ошибке после частичного streaming текст сохраняется вместе с
  `error_code = 'llm_error'`; builder исключает такие сообщения из следующего
  запроса.
- **Файлы:** `lib/features/chat/application/chat_controller.dart`,
  `lib/features/chat/application/chat_request_builder.dart`.
- **Тест:** `test/chat_controller_test.dart` — «retryLast повторяет запрос без
  partial-ответа с ошибкой».

### S03-019 — комментарий схемы

- Комментарий `ChatMessages` исправлен: partial-ответ сохраняется, а ошибка
  после него помечается `llm_error`; отменённый пустой ответ — `cancelled`.
- **Файл:** `lib/data/db/app_database.dart`.

### S03-020 — retry-политика

- Код: `maxRetries = 3` означает **3 попытки всего**, паузы только между ними —
  200 и 400 мс.
- ADR-019 и отчёт этапа приведены к этой семантике; «3 retry + 200/400/800» и
  «до 3 попыток» без уточнения удалены.
- **Файлы:** `lib/core/network/api_client.dart`, `docs/decisions.md`,
  `docs/stages/stage-03.md`.
- **Тест:** `test/llm_provider_test.dart` — retry только до SSE, отсутствие
  retry на 401.

## NIT

### S03-021 — отсутствие ключа

- До сетевого запроса проверяется `readApiKey`; если ключ нужен, но отсутствует,
  выставляется `api_key_missing` и запрос не уходит. Для loopback
  OpenAI-compatible ключ не требуется.
- **Тест:** `test/chat_controller_test.dart` — «без API-ключа запрос не уходит
  и возвращается api_key_missing».

### S03-022 — trim имени инструмента

- `LlmTool.definition` и `LlmToolRegistry.definitions` отдают то же trim-имя,
  по которому инструмент зарегистрирован.
- **Тест:** `test/llm_safety_test.dart` — «реестр инструментов возвращает
  trim-имя в definition».

### S03-023 — локализация чата

- Убраны хардкод `'Chat'` и нелокализованная подпись модели/токенов.
- Добавлены ARB-ключи `chatModelParams`, `chatRetry`, `chatApiKeyMissing`,
  `chatPrivateMessage`, `chatMarkPrivate`, `chatUnmarkPrivate` и др. (RU/EN).
- **Файлы:** `lib/features/chat/presentation/chat_screen.dart`, ARB/generated.

### S03-024 — неиспользуемые флаги провайдера

- Удалены `isLocal`/`supportsEmbeddings`; вместо них —
  `defaultEmbeddingModel` (nullable) и явная проверка loopback в
  `LlmEndpoint`.
- **Файлы:** `lib/features/llm/domain/llm_provider_type.dart`,
  `lib/features/llm/domain/llm_provider_config.dart`.

### S03-025 — `stream_options` fallback

- Для `openaiCompatible` при HTTP 400/422 запрос повторяется без
  `stream_options`; для OpenAI поведение не меняется.
- **Файл:** `lib/features/llm/data/openai_compatible_provider.dart`.
- **Тест:** `test/llm_provider_test.dart` — «stream_options повторяется без него
  при HTTP 400».

### S03-026 — навигация из пустого чата

- Widget-тест нажимает «Open settings» и проверяет, что открылся
  `/settings`, а не только наличие текста.
- **Файл:** `test/chat_screen_widget_test.dart`.

### S03-027 — лимит 60 000 символов

- Builder укладывает в лимит даже одно длинное сообщение, обрезая его хвост, и
  учитывает контекст в общем бюджете.
- **Тест:** `test/chat_request_builder_test.dart` — «не превышает 60 000
  символов одним длинным сообщением», «контекст учитывается в общем лимите».

### S03-028 — релевантность действия в ошибке

- «Open settings» показывается только для `no_config`, `provider_missing` и
  `api_key_missing`; для `llm_error` доступна кнопка «Повторить», для
  `cancelled` — только сообщение.
- **Файл:** `lib/features/chat/presentation/chat_screen.dart`.

## Обязательные проверки

Выполнено 2026-10-28 после форматирования только изменённых Dart-файлов
(Flutter 3.47.7, Dart 3.13.5):

| Команда | Результат |
|---------|-----------|
| `flutter analyze --fatal-infos` | **No issues found** |
| `flutter test` | **132/132 passed** |
| `flutter build windows --debug` | **success** (`build\windows\x64\runner\Debug\second_brain.exe`) |
| `git status --short` перед коммитом | только ожидаемые файлы кода/тестов |

CI-run [40636764573](https://github.com/HoudiwinG/second-brain/actions/runs/40636764573)
(`49bc00f`, включающий `14e63a7`) — **success**: `analyze-and-test` и
`build-windows` завершились успешно.

## Ограничения

- Живой сетевой smoke с реальными ключами OpenAI/Anthropic/Google не
  выполнялся; адаптеры проверены через `MockClient`.
- Ручной GUI-сценарий streaming/отмены в Windows после исправлений не
  прогонялся.
- TD-28 остаётся: в чате нет UI прикрепления заметок/задач/идей; privacy guard
  доступен через `sendMessage(contextRefs: ...)` и покрыт тестами, но обычный
  пользователь пока не может выбрать контекст.
- Выполнение tools и RAG-индексация — вне stage-03.
- Неблокирующие замечания повторного ревью S03R-001…S03R-004 относятся к
  stage-04; исходный формальный FAIL сохранён как исторический артефакт.
