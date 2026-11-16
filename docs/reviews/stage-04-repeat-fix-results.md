# Stage-04 — исправления после повторного ревью

- **Дата (UTC):** 2026-11-16
- **Автор:** agent-1 (OpenCode)
- **Источник находок:** [stage-04-repeat-review.md](stage-04-repeat-review.md) —
  повторное независимое ревью, вердикт **FAIL** (0 critical, 3 major,
  5 minor, 3 nit).
- **Характер документа:** self-check разработчика и доказательства. Это **не
  вердикт ревью**. Исходные вердикты `stage-04-review.md` и
  `stage-04-repeat-review.md` сохранены без изменений.
- **Проверяемое состояние:** `master` после `af023a1` (код исправлений —
  текущий коммит, документация — следующий).

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
- CI будет проверен после push; stage-05 не разблокирован до повторного
  независимого ревью.

## Ограничения

- Живые запросы к OpenAI/Anthropic/Google с реальными ключами не выполнялись;
  новые контракты проверены `MockClient` и формируемыми телами запросов.
- `S04R-006` покрыт тестом с задержанным репозиторием, но без реального
  многопоточного HTTP-таймаута.
