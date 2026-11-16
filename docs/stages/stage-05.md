# Stage-05 — Обучение

- **Дата:** 2026-11-16
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **done (self-check)**. Независимое ревью ещё не проводилось.
  Гейты: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **185/185**, `flutter build windows --debug` — success; CI-run
  `43892374452` (`9b96f58`) — success.
- **Предыдущий этап:** stage-04 — **PASS WITH COMMENTS** (0 MAJOR), stage-05
  разблокирован.
- **Схема БД:** **v7** (`learning_tracks`, `learning_sessions`).
- **ADR:** ADR-022.

## Цель и критерии приёмки

По `PROMPT.md`, модуль обучения:

- кастомные трекеры: пользователь задаёт цель, поля и шаги;
- AI-тренер генерирует roadmap по цели, разбивает на шаги, ведёт прогресс,
  периодически спрашивает статус и предлагает материалы;
- сессии: дата, длительность, заметки;
- приватность: трек с `is_private_for_llm = true` не отправляется в LLM;
- данные хранятся локально, ключи LLM остаются в secure storage.

Критерии выполнены в рамках self-check:

- [x] треки создаются/редактируются/удаляются (soft-delete);
- [x] шаги roadmap добавляются вручную и генерируются AI;
- [x] статус шага меняется, прогресс считается автоматически;
- [x] сессии добавляются и удаляются, суммарное время показывается;
- [x] кастомные поля хранятся как JSON;
- [x] AI-тренер: roadmap, материалы, check-in; приватный трек блокируется;
- [x] UI обучения заменяет заглушку;
- [x] миграция `v6 → v7` сохраняет данные.

## Что реализовано

- `lib/features/learning/domain/learning_track.dart` — `LearningTrack`,
  `LearningStep`, `LearningStepStatus`, `LearningTrackDraft`,
  `LearningRepository`.
- `lib/features/learning/domain/learning_session.dart` — `LearningSession`,
  `LearningSessionDraft`.
- `lib/data/repositories/learning_repository.dart` — Drift-репозиторий:
  CRUD треков, JSON roadmap/custom fields, статусы шагов, сессии,
  soft-delete, `forLlm`-фильтр приватных треков.
- `lib/features/learning/application/learning_trainer.dart` — AI-тренер:
  - `generateRoadmap(goal)` — строгий JSON-массив шагов, парсинг с code fence;
  - `suggestMaterials(track)` — 3-5 материалов/упражнений;
  - `checkIn(track)` — 2-3 вопроса о прогрессе и следующий шаг;
  - приватный трек не отправляется, ключ читается из `LlmConfigRepository`.
- `lib/features/learning/presentation/learning_screen.dart` — список треков,
  редактор, детальный экран с roadmap, сессиями и AI-панелью.
- `lib/app/di.dart` — `learningRepositoryProvider`, `learningTrainerProvider`.
- `lib/data/db/app_database.dart` — схема v7, таблицы, индексы, миграция.
- ARB RU/EN — все новые строки UI.

## Контракты и интерфейсы

- `LearningRepository`:
  - `listTracks({includeDeleted, forLlm})`, `getTrack`, `createTrack`,
    `updateTrack`, `setSteps`, `setStepStatus`, `softDeleteTrack`;
  - `listSessions`, `addSession`, `deleteSession`.
- `LearningTrainer`:
  - `generateRoadmap(String goal, {int stepCount})`
    → `Result<List<LearningStep>>`;
  - `suggestMaterials(LearningTrack)` → `Result<String>`;
  - `checkIn(LearningTrack)` → `Result<String>`.
- `learningRepositoryProvider` — `FutureProvider<LearningRepository>`;
  `learningTrainerProvider` — `FutureProvider<LearningTrainer>`.

## Схема БД на конец этапа

Схема **v7**:

- `learning_tracks`:
  - `id`, `title`, `goal`;
  - `roadmap_json` — JSON-массив шагов (`id`, `title`, `description`, `status`);
  - `custom_fields_json` — JSON-объект пользовательских полей;
  - `is_private_for_llm`, `created_at`, `updated_at`, `deleted_at`.
- `learning_sessions`:
  - `id`, `track_id` (FK cascade), `duration_minutes`, `notes`, `date`,
    `created_at`.
- Индексы:
  - `idx_learning_tracks_updated(updated_at)`;
  - `idx_learning_sessions_track_date(track_id, date)`.
- Миграция `v6 → v7`: создаёт обе таблицы и индексы, существующие данные не
  затрагивает. Guard `from > to || from > 7 || to > 7`.

## Зависимости, добавленные на этапе

Новых пакетов нет. Используются существующие Drift, Riverpod, HTTP/LLM-слой,
secure storage.

## Тесты

- `test/learning_repository_test.dart` — CRUD, JSON roadmap/fields, прогресс,
  сессии, soft-delete, forLlm, валидация.
- `test/learning_trainer_test.dart` — генерация roadmap из JSON/markdown,
  материалы/check-in, приватный трек без сети, отсутствие конфигурации.
- `test/learning_screen_widget_test.dart` — пустое состояние и переход в
  детальный экран.
- `test/db_migration_test.dart` — v6→v7, обновлены проверки v1→v7/v2→v7/
  v4→v7/v5→v7, guard v2→v8.

Итог: **185/185** тестов, analyze 0, Windows debug build success.

## Известные ограничения и техдолг

- Живые запросы AI-тренера к OpenAI/Anthropic/Google с реальными ключами не
  выполнялись; проверено на `MockClient`. Roadmap-парсер ожидает JSON-массив
  и ограничивает шаги 20.
- AI-тренер использует только default-провайдера; выбора модели для обучения
  пока нет.
- Нет глобального поиска по трекам (stage-08) и синхронизации.
- Заметки сессий не отправляются в LLM; в контекст тренера идут только
  заголовки/описания шагов и агрегированный прогресс.
- Нет отдельного напоминания о сессии; check-in показывается баннером при
  открытии трека, если последняя сессия была более 3 дней назад.
- TD-28 (UI выбора контекста в чате) не входит в stage-05 и остаётся
  accepted; триггер перенесён на более позднюю доработку чата.

## Как запустить и проверить этап

```powershell
$env:Path += ";C:\src\flutter\bin"
flutter pub get
flutter gen-l10n
dart run build_runner build
flutter analyze --fatal-infos
flutter test
flutter build windows --debug
```

В приложении: «Обучение» → «Новый трек» → заполнить цель → открыть трек →
добавить шаги/сессии или нажать AI-кнопки (нужен настроенный LLM-провайдер).

## Ссылки

- ADR-022 (обучение, JSON roadmap, AI-тренер, схема v7).
- Ревью: будет добавлено в `docs/reviews/stage-05-review.md` после
  независимой проверки.
