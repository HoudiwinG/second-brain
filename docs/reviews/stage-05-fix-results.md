# Stage-05 — результаты исправлений ревью

- **Дата (UTC):** 2026-11-16
- **Автор:** agent-1 (OpenCode)
- **Источник:** [stage-05-review.md](stage-05-review.md) — reviewer A **FAIL**
  (1 major), reviewer B **PASS WITH COMMENTS**; объединённый вердикт **FAIL**
  из-за `S05-001`.
- **Характер:** self-check разработчика, не вердикт ревью.
- **Ожидается:** повторное независимое ревью.

## Сводка

| ID | Severity | Статус | Исправление |
|----|----------|--------|-------------|
| S05-001 | MAJOR | fixed | JSON-бэкап v2: `learning_tracks`/`learning_sessions` в export/import/clear; v1 без обучения совместим; round-trip-тест |
| S05-002 | MINOR | fixed | `generateRoadmap(LearningTrack)` fail-closed для `isPrivateForLlm`; тест без сети |
| S05-003 | MINOR | fixed | AI-roadmap сохраняется через `await` в `try/catch`, busy до завершения, edit/delete блокируются |
| S05-004 | MINOR | fixed | `setStepStatus` в транзакции; идемпотентный soft-delete; `deleteSession` проверяет запись и обновляет трек; stable fallback id; уникальные synthetic id |
| S05-005 | MINOR | fixed | дата сессии нормализуется к UTC-полуночи календарного дня и отображается без TZ-сдвига |
| S05-006 | MINOR | fixed | edit/delete шага через `setSteps`, подтверждение удаления, ARB |
| S05-007 | MINOR | fixed | тесты `updateTrack`, битого JSON, дублей id, отсутствующего ключа, invalid/raw/fenced roadmap, приватного checkIn, v5→v7 с удалением learning-таблиц, обоих индексов, FK cascade |
| S05-008 | MINOR | fixed | отдельные ключи минут/диапазона/«Заменить»/tooltip статуса; мёртвые error-ключи удалены; AI-язык задокументирован как ограничение |
| S05-009 | MINOR | fixed | обновлены TD-22, ADR-022, context, stage-05; тесты/лимиты/check-in описаны точно |
| S05-010 | NIT | fixed | комментарий аудита перенесён к `ToolAuditEntries`; добавлены semantics/tooltip приватности и прогресса |
| S05-011 | NIT | fixed | сбалансированный парсер JSON-массива; индекс `learning_tracks(deleted_at, updated_at)`; валидация custom fields; отдельная ошибка диапазона |

## Ключевые изменения

### JSON-бэкап (S05-001)

`BackupService.version = 2`. В export добавлены:

- `learning_tracks` — id, title, goal, `roadmap_json`,
  `custom_fields_json`, `is_private_for_llm`, timestamps, `deleted_at`;
- `learning_sessions` — id, `track_id`, duration, notes, date, created_at.

Import: треки восстанавливаются до сессий, сессии без трека пропускаются,
дата нормализуется к UTC-полуночи. `_clearAll()` удаляет сессии и треки.
Для файлов version 1 массивы обучения необязательны; для version 2 —
обязательны. Добавлен round-trip-тест и тест импорта v1.

### Приватность (S05-002)

`LearningTrainer.generateRoadmap` принимает `LearningTrack` и проверяет
`isPrivateForLlm` до `_prepare`. Тест проверяет roadmap/materials/check-in
для приватного трека без сетевого вызова.

### Надёжность (S05-003/004/005)

- `_generateRoadmap` ждёт `setSteps`, ловит ошибки и держит `_aiBusy` до
  завершения; edit/delete заблокированы.
- `setStepStatus` выполняется в транзакции.
- `softDeleteTrack` идемпотентен.
- `deleteSession` проверяет существование и обновляет `updated_at` трека.
- `LearningStep.fromJson` принимает stable fallback id; дубли id
  нормализуются.
- Сессия хранится как UTC-полночь календарной даты; UI не делает `toLocal`.

### UI/тесты (S05-006…011)

- Добавлены edit/delete шага, отдельные ARB-ключи, корректные минуты,
  сообщение диапазона, кнопка «Заменить».
- Добавлены тесты репозитория, тренера, backup, v5→v7/v6→v7, проверки
  индексов и cascade.
- Исправлен парсер roadmap (сбалансированные `[]`, хвостовой `]`).
- Добавлен индекс `idx_learning_tracks_deleted`.

## Гейты

- `flutter analyze --fatal-infos` — **No issues found**.
- `flutter test` — **191/191**.
- `flutter build windows --debug` — **success**.
- CI — после push.

## Ограничения

- Живые LLM-запросы не выполнялись; тренер проверен `MockClient`.
- AI-промпты и тексты ошибок application-слоя остаются на русском; для EN-
  UI это задокументировано как ограничение (UI-подписи локализованы).
- Custom fields по-прежнему вводятся как `key=value`; значения с переводами
  строк не поддерживаются.
- TD-28 (UI контекста в чате) не входит в stage-05.
