# Stage-04 — исправления после повторного ревью

- **Дата (UTC):** 2026-11-16
- **Автор:** agent-1 (OpenCode)
- **Источник находок:** [stage-04-repeat-review.md](stage-04-repeat-review.md) —
  повторное независимое ревью, вердикт **FAIL** (0 critical, 3 major,
  5 minor, 3 nit).
- **Характер документа:** self-check разработчика и доказательства. Это **не
  вердикт ревью**. Исходные вердикты `stage-04-review.md` и
  `stage-04-repeat-review.md` сохранены без изменений.
- **Проверяемое состояние:** `master` @ `789a01f` (код, тесты и документация
  исправлений).

## Сводка

Все 11 находок повторного ревью закрыты в коде и тестах. Новых TD не
заводилось. Гейты: `flutter analyze --fatal-infos` — **No issues found**,
`flutter test` — **168/168**, `flutter build windows --debug` — **success**.
Stage-05 остаётся заблокированным до повторного независимого ревью.

| ID | Severity | Статус | Краткое доказательство |
|----|----------|--------|------------------------|
| S04R-001 | MAJOR | fixed | Anthropic группирует подряд идущие `LlmRole.tool` в один `user`-content со всеми `tool_result`; contract-тест на два параллельных вызова |
| S04R-002 | MAJOR | fixed | Google читает `functionCall.id`, сохраняет его в `LlmToolCall.id` и возвращает в `functionResponse.id`; ADR-021 исправлен; тесты на id и параллельные вызовы |
| S04R-003 | MAJOR | fixed | Добавлен маркер `MutatingLlmTool`; после успешного mutating-вызова ошибка получает `tool_side_effect`, Retry скрыт и `retryLast()` возвращает `false`; regression-тест |
| S04R-004 | MINOR | fixed | Приватные `create_note`/`create_task` возвращают только `id`/`private`, без title/remind_at; тесты |
| S04R-005 | MINOR | fixed | Добавлены regression-тесты `createThread`, `selectThread` и `deleteThread` во время блокирующего инструмента |
| S04R-006 | MINOR | fixed | Введены `_terminalRequestId` и единый `_cancelFuture`; поздние `cancel`/`complete`/`fail` не пишут второй assistant; тест с задержанным репозиторием |
| S04R-007 | MINOR | fixed | Pre-tool текст при отмене сохраняется с `errorCode = 'cancelled'` и исключается из контекста; regression-тест |
| S04R-008 | MINOR | fixed | Обновлены `context.md`, TD-28 (триггер stage-05), описание `search_data` (включая finance), ADR-021 и карта документации |
| S04R-009 | NIT | fixed | Комментарий `app_database.dart` описывает JSON-массив и legacy CSV |
| S04R-010 | NIT | fixed | In-memory БД в `llm_tools_test.dart` и `tool_runner_test.dart` закрываются в teardown |
| S04R-011 | NIT | fixed | Дубль `hintGlobalHotkey` удалён из RU/EN ARB, локализация перегенерирована |

## Детали по блокерам

### S04R-001 — Anthropic parallel tool results

`lib/features/llm/data/anthropic_provider.dart`:

- `_toolResultBlock` формирует один `tool_result`;
- `_isToolResultMessage` распознаёт `user`-content, состоящий только из
  `tool_result`;
- при сборке истории подряд идущие `LlmRole.tool` добавляются в content
  последнего `user`-сообщения.

Тест `test/llm_tool_mapping_test.dart` с двумя `tool_use` и двумя
`tool_result` проверяет ровно три сообщения и два блока в последнем.

### S04R-002 — Google functionCall.id

`lib/features/llm/data/google_provider.dart`:

- при разборе `functionCall` используется `call['id']`, если он непустой;
  `google_call_N` остаётся fallback;
- при сериализации `functionCall` пишется `id`;
- `functionResponse` получает `id` из `message.toolCallId`.

Тесты `test/llm_tool_mapping_test.dart` проверяют реальный `fc-42` из ответа,
`id` в `functionCall`/`functionResponse` и два параллельных вызова.
ADR-021 и отчёт stage-04 исправлены: Gemini может выдавать id, текущий
контракт сохраняет его.

### S04R-003 — retry после mutating tools

- В `llm_tool.dart` добавлен маркер `MutatingLlmTool`.
- `create_note`, `create_task` и `update_task_status` реализуют маркер.
- `ChatController._runTools` после успешного результата mutating-инструмента
  выставляет `_activeRequestMutated`.
- `_fail`/`_complete` используют `errorCode = 'tool_side_effect'`; UI не
  показывает Retry, `retryLast()` возвращает `false`.
- Regression-тест: успешный `create_note` → ошибка второго раунда → Retry
  запрещён, в БД остаётся одна заметка.

## Дополнительные исправления

- **S04R-004:** `CreateNoteTool` и `CreateTaskTool` не возвращают title/
  remind_at для `is_private: true`; возвращаются `id` и `private: true`.
- **S04R-005:** тесты в `chat_tool_loop_test.dart` для `createThread`,
  `selectThread` и `deleteThread` во время `_BlockingTool`.
- **S04R-006:** `_terminalRequestId` захватывается до ожидания БД; `cancel()`
  дедуплицируется через `_cancelFuture`. Тест в `chat_controller_test.dart`
  с задержанным `appendMessage` подтверждает одно assistant-сообщение.
- **S04R-007:** `_pendingPreToolText` выставляется при наличии tool calls;
  `cancel()` сохраняет такой partial с `cancelled`; тест с текстом перед
  tool call.
- **S04R-008:** обновлены `docs/context.md`, TD-28, `docs/INDEX.md`,
  `docs/stages/stage-04.md`, `docs/decisions.md`; описание `search_data`
  расширено финансовыми операциями.
- **S04R-009/010/011:** комментарий схемы, закрытие тестовых БД, удаление
  дубля ARB.

## Гейты

- `flutter analyze --fatal-infos` — **No issues found**.
- `flutter test` — **168/168 passed**.
- `flutter build windows --debug` — **success**
  (`build\windows\x64\runner\Debug\second_brain.exe`).
- CI-run [43829840626](https://github.com/HoudiwinG/second-brain/actions/runs/43829840626)
  (`789a01f`) — **success**, включая Windows debug build.
- Stage-05 не разблокирован до повторного независимого ревью.

## Комментарии повторного ревью (PASS WITH COMMENTS)

Повторное ревью исправлений дало **PASS WITH COMMENTS** (0 MAJOR):
reviewer A — 4 MINOR/3 NIT, reviewer B — 3 MINOR/5 NIT. Комментарии закрыты
дополнительным проходом:

| ID | Статус | Исправление |
|----|--------|-------------|
| S04F-A-001 / S04F-B-001 | fixed | `cancel()` в ветке `alreadyTerminal` синхронно завершает streaming-состояние; `_terminalErrorCode` сохраняет ошибку; тест проверяет `isStreaming=false`, пустой `streamingText` и повторный cancel без дубля |
| S04F-A-002 / S04F-B-002 | fixed | `_pendingPreToolText` выставляется уже при приходе `toolCallDeltas`, а не только в `onDone`; regression-тест с отменой до закрытия потока |
| S04F-A-003 | fixed | `_mutatedRequestId`/`_preToolRequestId` привязаны к requestId; поздние callbacks старого запроса не меняют флаги нового |
| S04F-A-004 / S04F-B-003 | fixed | `stage-04.md` больше не утверждает общую фильтрацию tool results; описание соответствует ADR-021 |
| S04F-A-005 | fixed | `dart run build_runner build` перегенерировал `app_database.g.dart` |
| S04F-A-006 | fixed | Синтетический `google_call_N` не отправляется на провод; добавлен fallback-тест и тест двух вызовов одной функции с разными id |
| S04F-A-007 / S04F-B-004 | fixed | Документация лимита раундов синхронизирована (`llm_error`/`tool_side_effect`); тест переименован |
| S04F-B-005 | fixed | `retryLast()` проверяет `errorCode` последнего сообщения; тест после смены треда |
| S04F-B-006 | fixed | Тест лимита переименован; тест отмены проверяет состояние; добавлен Google-тест двух вызовов одной функции |
| S04F-B-007 | fixed | `context.md` обновлён; HEAD указывается как текущий docs-коммит |
| S04F-B-008 | fixed | Комментарий `chat_messages.error_code` перечисляет `llm_error`/`tool_side_effect`/`cancelled` |

Гейты после дополнительного прохода: analyze 0, **172/172** тестов, Windows
debug build success. Ожидается финальная независимая проверка.

## Ограничения

- Живые запросы к OpenAI/Anthropic/Google с реальными ключами не выполнялись;
  новые контракты проверены `MockClient` и формируемыми телами запросов.
- `S04R-006` покрыт тестом с задержанным репозиторием, но без реального
  многопоточного HTTP-таймаута.
