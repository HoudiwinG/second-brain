# Повторное независимое ревью: Stage-03 (Repeat Review)

- **Дата (UTC):** 2026-10-28
- **Ревьюер:** independent repeat reviewer (Gemini 4 Argon, OpenCode)
- **Проверяемое состояние:** ветка `master` @ `3089b79` (код и тесты исправлений — коммит `14e63a7`, документация исправлений — коммиты `49bc00f` и `3089b79`)
- **Исходное ревью:** [docs/reviews/stage-03-review.md](stage-03-review.md) — вердикт **FAIL** (2026-10-25, два независимых прохода, 3 MAJOR, 17 MINOR, 8 NIT)
- **Self-check разработчика:** [docs/reviews/stage-03-fix-results.md](stage-03-fix-results.md)
- **Отчёт этапа:** [docs/stages/stage-03.md](../stages/stage-03.md)

## Область и ограничения проверки

- **Область:** полная независимая сверка всех 28 находок `S03-001`…`S03-028` по фактическому коду и тестам (`git diff 6906c2d..14e63a7`), проверка на регрессии и новые дефекты в изменённых модулях, сверка документации и ADR-018/019/020 (`14e63a7..3089b79`), локальный прогон обязательных гейтов (`analyze`, `test`, `build windows`) и независимая проверка CI через GitHub REST API.
- **Сохранение истории:** исходный файл `docs/reviews/stage-03-review.md` и его вердикт **FAIL** оставлены **без изменений** как исторический артефакт первого ревью.
- **Ограничения:** живые сетевые запросы к реальным API OpenAI, Anthropic и Google с боевыми ключами не выполнялись (все адаптеры и транспорт проверены на `MockClient` и unit/widget-тестах); ручной интерактивный GUI-прогон Windows-приложения с живым SSE-стримингом не проводился.

---

## Итог повторного ревью

- **Вердикт:** **PASS** (с неблокирующими замечаниями: 0 CRITICAL, 0 MAJOR, 2 MINOR, 2 NIT)
- **Статус исходных находок S03-001…S03-028:** **28 / 28 verified (закрыты)**
- **Новые находки повторного ревью:** CRITICAL: 0, MAJOR: 0, MINOR: 2 (`S03R-001`, `S03R-002`), NIT: 2 (`S03R-003`, `S03R-004`)
- **Рекомендация по stage-04:** **РАЗБЛОКИРОВАТЬ stage-04.** Все три блокера (`S03-001`, `S03-002`, `S03-003`) и все 25 остальных замечаний первого ревью устранены и покрыты тестами.

---

## Результаты локальных гейтов и проверки дерева

Все команды выполнены независимо из корня репозитория `C:\Users\a.chernov\Projects\second-brain` на `HEAD = 3089b79`:

| Проверка / команда | Результат | Детали |
|---|---|---|
| `git status --short` (до и после проверок) | **Clean** | Рабочее дерево чистое (`HEAD` = `3089b79` содержит и код `14e63a7`, и документацию `49bc00f`/`3089b79`; line-ending шум `windows/flutter/generated_plugin_registrant.h` после сборки откатан). |
| `flutter analyze --fatal-infos` | **PASS (0 issues)** | `Analyzing second-brain... No issues found! (ran in 14.9s)` |
| `flutter test` | **PASS (132 / 132)** | `00:12 +132: All tests passed!` |
| `flutter build windows --debug` | **PASS** | `√ Built build\windows\x64\runner\Debug\second_brain.exe (13,4s)` |

---

## Независимая проверка CI

Проверено независимо через GitHub REST API (`https://api.github.com/repos/HoudiwinG/second-brain/actions/runs/<id>`) с использованием системного git credential helper (без вывода токена):

- **Run `40636764573`** (`head_sha: 49bc00f`, включает код и тесты `14e63a7`): `status = completed`, `conclusion = success`.
  - Job `analyze-and-test`: `completed / success`
  - Job `build-windows`: `completed / success`
- **Run `40637438577`** (`head_sha: 3089b79`, текущий `HEAD`): `status = completed`, `conclusion = success`.
  - Job `analyze-and-test`: `completed / success`
  - Job `build-windows`: `completed / success`

---

## Верификация находок S03-001…S03-028

| ID | Исходная критичность | Статус | Доказательства в коде и тестах |
|---|---|---|---|
| **S03-001** | MAJOR | **verified** | В `lib/features/chat/application/chat_controller.dart:223-266` удалён глобальный ранний выход по `errorCode == 'llm_error'`; `sendMessage` возвращает `Future<bool>` и сбрасывает `errorCode: null` на старте (`:236-238`). Ошибка чтения ключа проверяется локально через `keyReadFailed` (`:327-338`). Добавлен `retryLast()` (`:269-306`). В `lib/features/chat/presentation/chat_screen.dart:43-54` `_input.clear()` вызывается только при `if (accepted)`. Тесты: `test/chat_controller_test.dart:220-264` («ошибка провайдера сохраняет маркер и не блокирует отправку»), `:266-315` (`retryLast`). |
| **S03-002** | MAJOR | **verified** | Сборка истории вынесена в `buildChatRequestMessages` (`lib/features/chat/application/chat_request_builder.dart:19-107`): фильтрация `errorCode == null && !isPrivateForLlm && content.isNotEmpty`, окно `maxHistoryMessages = 40`, лимит `maxHistoryChars = 60000`, отбрасывание ведущих не-`user` сообщений (`:78`, `:89-91`, `:118-120`), склейка подряд идущих одинаковых ролей через `\n\n` (`:80-85`). Тесты: `test/chat_request_builder_test.dart:25-95` (6 unit-тестов). |
| **S03-003** | MAJOR | **verified** | В `ChatController` (`lib/features/chat/application/chat_controller.dart:77-79`, `:107-180`) введены `_activeRequestId` и `_sending`. `createThread`, `selectThread` и `deleteThread` (для активного треда) при `_sending` сначала выполняют `await cancel()`. Колбэки стрима (`:418-450`), `_complete` (`:513-546`), `_fail` (`:548-566`) и `_refreshMessages` (`:589-612`) проверяют `_isActive(requestId)` и `current.activeThreadId == threadId`. Тест: `test/chat_controller_test.dart:355-410`. |
| **S03-004** | MINOR | **verified** | В `lib/data/db/app_database.dart:467-471` добавлен partial unique index `CREATE UNIQUE INDEX IF NOT EXISTS idx_llm_configs_default ON llm_provider_configs(is_default) WHERE is_default = 1`, а в миграции `< 5` вызывается `_normalizeDefaultConfigs()` (`:399-404`, `:475-485`). В `lib/data/repositories/llm_config_repository.dart:115,169-171,195,220,256-273` `_ensureDefaultExists(avoidId: ...)` поддерживает ровно один default. `RepositoryGuard.guard` ловит `on Object` (`lib/data/repositories/repository_guard.dart:14-18`). Тесты: `test/llm_repositories_test.dart:213-275`, `:363-390`; `test/db_migration_test.dart:336-463`. |
| **S03-005** | MINOR | **verified** | В `lib/features/llm/domain/llm_provider_config.dart:19,37` добавлен `hasApiKey`. В `lib/features/llm/presentation/llm_settings_section.dart:135` карточка выводит `llmApiKeyStored` / `llmApiKeyNotStored`; в диалоге редактирования (`:318-320`, `:403-423`) есть кнопка `llmApiKeyDelete`, передающая `apiKey: ''`, что в `DriftLlmConfigRepository.update` (`:137-144`) вызывает `_deleteSecret`. Тесты: `test/llm_settings_widget_test.dart:57`, `:143-205`; `test/llm_repositories_test.dart:91-131`. |
| **S03-006** | MINOR | **verified** | Добавлен `LlmContextRef` и `DriftLlmContextLoader` (`lib/features/llm/application/llm_context_loader.dart:13-121`), зарегистрированный в `llmContextLoaderProvider` (`lib/app/di.dart:111-115`). `ChatController.sendMessage` принимает `List<LlmContextRef> contextRefs` (`lib/features/chat/application/chat_controller.dart:225`, `:380-386`), загружает сущности и их `isPrivateForLlm` из БД и фильтрует через `PrivacyGuard.filter`. Тест: `test/chat_controller_test.dart:141-182`. |
| **S03-007** | MINOR | **verified** | В таблицу `ChatMessages` (`lib/data/db/app_database.dart:290-292`) и доменную модель `ChatMessage` (`lib/features/chat/domain/chat_message.dart:14,27`) добавлено поле `isPrivateForLlm`. Репозиторий реализует `setMessagePrivate` (`lib/data/repositories/chat_repository.dart:179-192`), контроллер — `setMessagePrivate` (`lib/features/chat/application/chat_controller.dart:631-657`), UI — кнопку переключения приватности (`lib/features/chat/presentation/chat_screen.dart:461-489`), `buildChatRequestMessages` исключает такие сообщения (`chat_request_builder.dart:27`). Тесты: `test/chat_controller_test.dart:448-474`, `test/llm_repositories_test.dart:499-532`. |
| **S03-008** | MINOR | **verified** | В `lib/data/repositories/llm_config_repository.dart:90-122` при сбое транзакции `create` вызывается `_deleteSecretBestEffort(secretRef)`; в `update` (`:134-183`) предварительно читается `oldKey`, а при ошибке БД вызывается `_restoreSecret(current.secretRef, oldKey)`. Все обращения к `_secrets` проверяют `Result` (`:275-307`). Тесты с SQLite-триггерами `BEFORE INSERT`/`BEFORE UPDATE`: `test/llm_repositories_test.dart:302-361`. |
| **S03-009** | MINOR | **verified** | В `lib/features/chat/application/chat_controller.dart:397,683-684` `_effectiveModel(thread, config)` возвращает `thread.model` только при `config.id == thread.providerConfigId`, иначе берёт `config.model` выбранного fallback-провайдера. Аналогично в UI (`lib/features/chat/presentation/chat_screen.dart:176-181`). Тест: `test/chat_controller_test.dart:412-446`. |
| **S03-010** | MINOR | **verified** | В `lib/features/llm/presentation/llm_settings_section.dart:221,283-333` диалог переведён на `Form` + `TextFormField` с валидаторами `_required`, `_validateBaseUrl`, `_validateMaxTokens`. При невалидном вводе или ошибке `onSave` диалог не закрывается, введённый текст сохраняется в контроллерах. Тесты: `test/llm_settings_widget_test.dart:111-141`, `:175-186`. |
| **S03-011** | MINOR | **verified** | В `lib/features/chat/presentation/chat_screen.dart:186-235` при `configs.isEmpty` рендерится `_ConfigBanner`, но `_ThreadBar` и `_MessagesView` остаются видимыми; блокируется только `_Composer(enabled: hasConfigs)`. Тест: `test/chat_screen_widget_test.dart:17-85`. |
| **S03-012** | MINOR | **verified** | Добавлены регрессионные тесты на все критичные переходы: повтор после `llm_error`, `retryLast` после partial+error, double-send guard, `createThread` во время streaming, fallback модели, отсутствие ключа, компенсация секретов, обрезка истории/ролей/бюджета, миграция `v4 → v5`. Всего `132/132` тестов. |
| **S03-013** | MINOR | **verified** | В `lib/features/chat/application/chat_controller.dart:228-232` и `:270-282` проверка `if (_sending) return false;` и установка `_sending = true` выполняются синхронно до первого `await`. Тест: `test/chat_controller_test.dart:317-353`. |
| **S03-014** | MINOR | **verified** | Добавлена колонка `embedding_model` (`lib/data/db/app_database.dart:228`), `defaultEmbeddingModel` в `LlmProviderType` (`lib/features/llm/domain/llm_provider_type.dart:9,16,29,51`), поле в UI (`llm_settings_section.dart:381-387`), использование в `OpenAiCompatibleProvider._embeddingModel` (`openai_compatible_provider.dart:130-134`) и `GoogleProvider._embeddingModelId` (`google_provider.dart:144-150`). Тесты: `test/llm_provider_test.dart:226-251`, `:370-396`. |
| **S03-015** | MINOR | **verified** | Создан `LlmEndpoint` (`lib/features/llm/domain/llm_endpoint.dart:8-36`): `isValid` разрешает `https` для любых хостов и `http` только для `localhost`, `127.0.0.1`, `::1`, `[::1]`. Проверяется в `DriftLlmConfigRepository._validate` (`llm_config_repository.dart:361-367`) и в форме (`llm_settings_section.dart:287-292`). Тесты: `test/llm_safety_test.dart:53-73`, `test/llm_repositories_test.dart:277-300`. |
| **S03-016** | MINOR | **verified** | В `lib/data/repositories/chat_repository.dart:135-138` сообщения сортируются по `OrderingTerm.asc(m.createdAt), OrderingTerm.asc(m.id)` (и треды по `updatedAt DESC, id DESC` в `:41-44`); индекс обновлён на `(thread_id, created_at, id)` (`app_database.dart:463-465`). `appendMessage` обёрнут в `_db.transaction` с обновлением `chatThreads.updatedAt` (`chat_repository.dart:153-175`). Тест: `test/llm_repositories_test.dart:499-532`. |
| **S03-017** | MINOR | **verified** | `AppException.toString()` возвращает только `'$runtimeType: $message'` без `cause` (`lib/core/error/app_exception.dart:17`). `AppLogger._safe` для не-`AppException` выводит только `error.runtimeType.toString()` (`lib/core/logging/app_logger.dart:46-47`). Тест: `test/llm_safety_test.dart:35-44`. |
| **S03-018** | MINOR | **verified** | В `ChatController._fail` (`lib/features/chat/application/chat_controller.dart:560`) partial-ответ всегда сохраняется с `errorCode: 'llm_error'`. `buildChatRequestMessages` отфильтровывает сообщения с `errorCode != null` (`chat_request_builder.dart:26`). Тест: `test/chat_controller_test.dart:266-315`. |
| **S03-019** | MINOR | **verified** | Doc-комментарий над `ChatMessages` в `lib/data/db/app_database.dart:267-271` приведён в соответствие с фактическим поведением `cancel()` и `_fail()`. |
| **S03-020** | MINOR | **verified** | В `lib/core/network/api_client.dart:20,38,95,145-148` `maxRetries = 3` означает 3 попытки всего (первая + до 2 повторов) с паузами 200 мс и 400 мс. ADR-019 (`docs/decisions.md:872-873`), `docs/stages/stage-03.md:111-112` и `docs/context.md:81-82` полностью согласованы с кодом. |
| **S03-021** | NIT | **verified** | В `ChatController._startRequest` (`lib/features/chat/application/chat_controller.dart:339-343`) до сетевого вызова проверяется `LlmEndpoint.requiresApiKey(config.type, config.baseUrl)`; при пустом ключе возвращается `false` и выставляется `api_key_missing`. Тест: `test/chat_controller_test.dart:476-511`. |
| **S03-022** | NIT | **verified** | В `lib/features/llm/tools/llm_tool_registry.dart:18-23` и `:48-55` `name.trim()` применяется и в `LlmTool.definition`, и в `LlmToolRegistry.definitions`. Тест: `test/llm_safety_test.dart:46-51`. |
| **S03-023** | NIT | **verified** | В `lib/features/chat/presentation/chat_screen.dart:64,324` создание треда использует `lcm.chatNewThread`, а подпись модели и лимита токенов — `lcm.chatModelParams(modelLabel!, config!.maxTokens)`. Ключи добавлены в `lib/l10n/app_en.arb` и `lib/l10n/app_ru.arb`. |
| **S03-024** | NIT | **verified** | Из `LlmProviderConfig` и `LlmProviderType` удалены `isLocal` и `supportsEmbeddings`; введены `defaultEmbeddingModel` и проверки `LlmEndpoint`. |
| **S03-025** | NIT | **verified** | В `OpenAiCompatibleProvider.streamChat` (`lib/features/llm/data/openai_compatible_provider.dart:38-58`) для `LlmProviderType.openaiCompatible` при `NetworkException` со статусом `400` или `422` запрос повторяется без `stream_options`. Тест: `test/llm_provider_test.dart:253-297`. |
| **S03-026** | NIT | **verified** | Widget-тест `test/chat_screen_widget_test.dart:81-84` нажимает `'Open settings'` и проверяет переход на маршрут `/settings` (`expect(find.text('Settings destination'), findsOneWidget)`). |
| **S03-027** | NIT | **verified** | В `lib/features/chat/application/chat_request_builder.dart:40-73` и `_enforceCharLimit` (`:109-133`) лимит `maxHistoryChars = 60000` соблюдается с учётом `contextSuffix` и даже для одного сверхдлинного сообщения. Тесты: `test/chat_request_builder_test.dart:63-70`, `:84-94`. |
| **S03-028** | NIT | **verified** | В `_ErrorBanner` (`lib/features/chat/presentation/chat_screen.dart:518-542`) кнопка `chatOpenSettings` отображается только для `no_config`, `provider_missing`, `api_key_missing`; для `llm_error` отображается кнопка `chatRetry` («Повторить»); для `cancelled` кнопки действий скрыты. |

---

## Новые находки и неблокирующие замечания (S03R)

Критичных (`CRITICAL`) и блокирующих (`MAJOR`) дефектов или регрессий не обнаружено. Ниже зафиксированы 2 `MINOR` и 2 `NIT` замечания для учёта на stage-04 / следующих проходах.

### [MINOR] S03R-001: Контекст приклеивается к старому user-сообщению, если последнее сообщение истории — от ассистента (`retryLast` / ручная история)

- **Категория:** E — формирование запроса / крайние случаи
- **Где:** `lib/features/chat/application/chat_request_builder.dart:94-104`, `test/chat_request_builder_test.dart:72-82`
- **Что не так:** когда `contextSuffix` непустой, `buildChatRequestMessages` ищет `final index = aligned.lastIndexWhere((message) => message.role == LlmRole.user)` и дописывает `\n\n[context]\n...` внутрь `aligned[index]`. Если последним сообщением в `aligned` является `assistant` (например, в тесте `chat_request_builder_test.dart:72-82` или при вызове `retryLast()`, когда в треде уже есть успешная пара `user` → `assistant`), контекст модифицирует **прошлое** сообщение пользователя, за которым уже следует ответ ассистента, а вся история заканчивается сообщением `assistant`.
- **Почему не блокер (MINOR):** в штатном потоке `sendMessage` перед вызовом `buildChatRequestMessages` в БД всегда записывается новое `user`-сообщение (`chat_controller.dart:348-370`), поэтому в `sendMessage` последним элементом `aligned` гарантированно является только что отправленное сообщение пользователя. Кроме того, на stage-03 UI ещё не передаёт `contextRefs` (TD-28).
- **Предлагаемое исправление (на stage-04 при подключении UI контекста):** либо прикреплять контекст только тогда, когда последнее сообщение имеет роль `user` (или добавлять его отдельным завершающим `user`-блоком), либо запретить `retryLast()` на треде, где последнее неисправленное сообщение уже является успешным ответом `assistant`.

### [MINOR] S03R-002: Удаление провайдера в настройках во время активного streaming-ответа в чате приводит к ложному fallback в UI или `provider_missing`

- **Категория:** E — согласованность контроллеров
- **Где:** `lib/features/llm/application/llm_config_controller.dart:52-67`, `lib/features/chat/application/chat_controller.dart:314-318, 664-670`
- **Что не так:** если пользователь запустил долгий streaming-ответ в чате, перешёл в раздел «Настройки» (`StatefulShellRoute.indexedStack` сохраняет оба дерева виджетов активными) и удалил единственного (или текущего) провайдера, `LlmConfigController.delete` не останавливает активный запрос в `ChatController`. Поток дочитывается в фоне, а в шапке чата `_ThreadBar` сразу начинает отображать fallback-модель (или скрывает подпись при пустом списке).
- **Почему не блокер (MINOR):** БД и история не повреждаются (`ON DELETE SET NULL` на `chat_threads.provider_config_id` отрабатывает штатно, `ChatController` проверяет актуальный конфиг при следующем запросе).
- **Предлагаемое исправление:** при удалении конфигурации в `LlmConfigController.delete` (или через listener в `ChatController`) отменять активный streaming, если он шёл через удаляемый `providerConfigId`.

### [NIT] S03R-003: `_Composer` оставляет текстовое поле ввода активным во время streaming, если провайдеры не пусты, и наоборот — активирует его во время streaming при пустом списке

- **Категория:** E — UX/виджеты
- **Где:** `lib/features/chat/presentation/chat_screen.dart:567, 576`
- **Что не так:** в `_Composer.build` условие активности `TextField` записано как `enabled: enabled || isStreaming`. Когда `enabled == false` (нет провайдеров) и `isStreaming == false`, поле отключено, как и задумано. Но логически `TextField.enabled` не нуждается в `|| isStreaming` (достаточно `enabled: enabled`), тогда как для кнопки отправки/остановки `canSend = enabled || isStreaming` (`:567`) как раз оправдано, чтобы кнопка Stop оставалась нажимаемой даже при удалении конфига.
- **Предлагаемое исправление:** для `TextField` оставить `enabled: enabled`, сохранив `canSend = enabled || isStreaming` только для `IconButton.filled`.

### [NIT] S03R-004: Дублирующийся ключ `"hintGlobalHotkey"` в `app_en.arb` и `app_ru.arb`

- **Категория:** E — локализация / чистота ARB
- **Где:** `lib/l10n/app_en.arb:33, 148`, `lib/l10n/app_ru.arb:33, 148`
- **Что не так:** ключ `"hintGlobalHotkey"` определён дважды в обоих ARB-файлах (на строке 33 со старым текстом stage-00 и на строке 148 с текстом stage-02). Это наследие прошлых этапов (не внесено в `14e63a7`), JSON-парсер `gen-l10n` молча берёт второе значение.
- **Предлагаемое исправление:** удалить дублирующую строку 33 в `app_en.arb` и `app_ru.arb` при следующем обновлении ARB.

---

## Финальный вердикт и рекомендация

- **Финальный вердикт:** **PASS**
- **Статус stage-04:** **РАЗБЛОКИРОВАН (UNBLOCKED).** Разработчик может переходить к реализации stage-04 («Инструменты ассистента»).
