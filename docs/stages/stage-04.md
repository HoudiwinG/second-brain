# Stage-04 — Инструменты ассистента

- **Дата:** 2026-10-29 (начало)
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **реализация готова, гейты зелёные.** Предыдущий этап: stage-03 —
  повторное ревью PASS (`docs/reviews/stage-03-repeat-review.md`). Независимого
  ревью stage-04 ещё нет.
- **Коммит:** см. `git log` (коммит `feat(stage-04)`).

## Реализовано

- `LlmToolCallAccumulator` (`lib/features/llm/domain/llm_provider.dart`) —
  сборка tool calls из дельт; используется в `complete()` и контроллере.
- Инструменты (`lib/features/llm/tools/built_in/`), базовый класс
  `LlmToolBase` в `llm_tool_registry.dart`:
  - `create_task` (с `remind_at`), `create_note`, `update_task_status`
    (приватные задачи недоступны и по id), `search_data` (всегда
    `forLlm: true`), `summarize_mail_mock` (фиксированный мок, `source: mock`).
- `ToolRunner` (`lib/features/llm/application/tool_runner.dart`): неизвестный
  инструмент, некорректный JSON, ошибки валидации и исключения инструмента не
  прерывают запрос — модель получает `{"ok": false, "error": ...}`.
- Аудит: схема **v6**, таблица `tool_audit_log` (`ToolAuditEntries`),
  `DriftToolAuditRepository`. Пишутся имя инструмента, статус, имена
  аргументов (без значений), `entity_id`, время.
- Цикл в `ChatController`: `_streamRound` → при tool calls `_runTools` →
  следующий раунд. Лимит `maxToolRounds = 3` раундов инструментов; сверх
  лимита запрос завершается `llm_error` с сохранением partial-текста.
- Провайдеры: Anthropic отправляет `tool_use`/`tool_result`; Google отправляет
  `functionCall`/`functionResponse` и разбирает `functionCall` из ответа
  (Gemini не выдаёт id — используется синтетический `google_call_N`).
  OpenAI-compatible уже сериализовал `tool`/`tool_calls`.
- DI: `llmToolRegistryProvider` стал `FutureProvider` и регистрирует все
  инструменты; `toolAuditRepositoryProvider` — журнал аудита.

## Тесты

- `test/llm_tools_test.dart` — инструменты, приватность поиска, аудит-репозиторий.
- `test/tool_runner_test.dart` — неизвестный инструмент, битый JSON, аудит
  без значений, ошибка валидации.
- `test/chat_tool_loop_test.dart` — tool call → заметка → финальный ответ;
  лимит раундов.
- `test/llm_tool_mapping_test.dart` — тела запросов Anthropic/Google и разбор
  `functionCall` Gemini.
- `test/db_migration_test.dart` — v6, миграция v5 → v6 с сохранением данных.

## Гейты

- `flutter analyze --fatal-infos` — **No issues found**.
- `flutter test` — **154/154 passed**.
- `flutter build windows --debug` — **success** (2026-10-29). Первая попытка
  упала с `LNK1168`: `second_brain.exe` был занят запущенным процессом, его
  остановили вручную; повторная сборка прошла.
- `dart run build_runner build` выполнен; `app_database.g.dart` перегенерирован.

## Ограничения

- Отмена во время цикла останавливает следующий раунд, но уже выполненные
  инструменты не откатываются (создание задачи/заметки остаётся в БД).
- Tool-сообщения и вызовы не сохраняются в `chat_messages`: в истории только
  user/assistant, трассировка — в `tool_audit_log`.
- UI подтверждения действий не реализован (инструменты не удаляют данных).
- `summarize_mail_mock` не подключён к реальной почте (stage-06).
- Живые запросы к API с tool calls не выполнялись: проверено через `MockClient`.
- Неблокирующие замечания stage-03 S03R-001…S03R-004 не закрывались в этом
  этапе, кроме случаев, описанных выше (не относятся к инструментам).

## Цель этапа

По `PROMPT.md`: создание задач/заметок/напоминаний, поиск по данным,
суммирование (на моках почты), обновление трекера. Каждое действие ассистента
проходит через реестр инструментов и попадает в аудит без содержимого
приватных полей.

## Объём

Входит:

- цикл tool calls в `ChatController`: ответ модели с `toolCalls` → выполнение
  через реестр → результаты возвращаются модели → финальный текст;
- инструменты:
  - `create_task` — задача, опционально с `remind_at` (напоминание = задача с
    `remindAt`, отдельной сущности нет);
  - `create_note` — заметка;
  - `search_data` — поиск по заметкам/задачам/идеям через `SearchRepository`;
  - `update_task_status` — обновление статуса задачи (трекер);
  - `summarize_mail_mock` — суммирование писем из фиксированного мок-набора
    (реальной почты на этом этапе нет, OAuth — stage-06);
- аудит: таблица `tool_audit_log` (схема **v6**);
- регистрация инструментов в DI;
- тесты на каждый инструмент, цикл, аудит и приватность.

Не входит:

- UI подтверждения действий (отложено; все инструменты этапа либо создают
  сущности, либо меняют только статус, без удаления);
- сохранение tool-сообщений в `chat_messages` (в истории хранятся только
  user/assistant; трассировка — в аудите);
- реальная почта, RAG-индексация (stage-06/RAG).

## Ключевые решения

1. **Сборщик tool calls публичный.** `_ToolCallBuilder` из
   `llm_provider.dart` выносится в `LlmToolCallAccumulator`, его используют и
   `LlmProvider.complete`, и контроллер при streaming.
2. **Лимит раундов.** Не больше `maxToolRounds = 3` вызовов модели на один
   пользовательский запрос; после лимита — `llm_error` без сохранения
   незавершённых tool-вызовов.
3. **Приватность.** Инструменты чтения (`search_data`) фильтруют
   `isPrivateForLlm = true` на уровне репозитория (`forLlm: true`). Результаты
   инструментов в модель проходят ту же фильтрацию, что и контекст чата.
4. **Аудит без содержимого.** В `tool_audit_log` пишутся: имя инструмента,
   статус (`ok` / `error` / `unknown_tool` / `invalid_args`), список **имён**
   аргументов, id созданной/изменённой сущности, время. Значения аргументов
   (тексты, заголовки) не пишутся.
5. **Ошибки инструмента не роняют запрос.** Результат с ошибкой уходит модели
   как `tool`-сообщение с кодом ошибки; модель может ответить пользователю.
6. **Схема v6.** Миграция `v5 → v6` создаёт `tool_audit_log` с индексом по
   `created_at`. Guard `from > to || from > 6 || to > 6` сохраняется.

## План по шагам

| # | Шаг | Проверка |
|---|-----|----------|
| 1 | Этот план в `docs/stages/stage-04.md` | — |
| 2 | `LlmToolCallAccumulator` вынесен, `complete()` переведён на него | существующие provider-тесты зелёные |
| 3 | Инструменты `create_task`, `create_note`, `update_task_status` + тесты | unit-тесты на in-memory БД |
| 4 | `search_data` с фильтром приватности + тест | тест: приватная сущность не возвращается |
| 5 | `summarize_mail_mock` | тест на фиксированный ответ |
| 6 | Схема v6, `tool_audit_log`, `ToolAuditRepository` | миграция v5→v6 и onCreate тесты |
| 7 | `ToolRunner`: выполнение, аудит, ошибки, unknown tool | тесты статусов аудита |
| 8 | Цикл в `ChatController` с лимитом раундов | тесты на mock-провайдере: tool → текст; лимит; отмена |
| 9 | Регистрация инструментов в DI | `flutter analyze`, `flutter test` |
| 10 | Гейты, отчёт этапа, ADR-021/022, `context.md`, `INDEX.md`, commit, push, CI | CI success |

## Критерии приёмки

- модель может создать задачу, заметку и задачу с напоминанием через tool
  call, и пользователь видит результат в БД;
- `search_data` не возвращает приватные сущности;
- каждый вызов инструмента записан в `tool_audit_log` без значений аргументов;
- цикл останавливается на лимите раундов и не зависает;
- отмена и смена треда во время цикла работают как в stage-03;
- `flutter analyze --fatal-infos`, `flutter test`, `flutter build windows --debug`
  зелёные; CI зелёный.

## Журнал выполнения

- 2026-10-29: план зафиксирован (шаг 1).
- 2026-10-29: шаг 2 — `LlmToolCallAccumulator`; шаги 3–5 — инструменты
  `create_task`, `create_note`, `update_task_status`, `search_data`,
  `summarize_mail_mock` с тестами.
- 2026-10-29: шаг 6 — схема v6, `tool_audit_log`, `DriftToolAuditRepository`;
  исправлен порядок миграции (индекс аудита создаётся после таблицы).
- 2026-10-29: шаг 7 — `ToolRunner`; провайдеры Anthropic/Google получили
  сериализацию tool-сообщений; Google разбирает `functionCall`.
- 2026-10-29: шаги 8–9 — цикл в `ChatController`, DI-регистрация.
- 2026-10-29: `flutter analyze` и `flutter test` (154/154) зелёные; сборка
  Windows блокируется запущенным процессом (см. «Гейты»).
