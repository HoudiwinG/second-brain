# Stage-08 — Глобальный поиск + аналитика

- **Дата:** 2026-11-17
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **PASS WITH COMMENTS (0 MAJOR).** Первое ревью A/B — FAIL
  (фильтры после LIMIT, backfill, валюты, лимит писем); блокеры исправлены,
  финальное ревью A/B — PASS WITH COMMENTS (см.
  [reviews/stage-08-final-review.md](../reviews/stage-08-final-review.md)).
  Гейты: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **241/241**, `flutter build windows --debug` — success; CI
  `44028937569` (`d10dec0`) — success, оба job'а.
- **Предыдущий этап:** stage-07 — **PASS WITH COMMENTS (0 MAJOR)**.
- **Схема БД:** **v8** без изменений.
- **ADR:** ADR-025.

## Цель и критерии приёмки

По `PROMPT.md`, stage-08:

- единый поиск по заметкам, задачам, идеям, финансам, обучению, истории чата,
  почте (вложения пока не реализованы);
- фильтры по типу/дате;
- аналитика по локальным данным.

Критерии self-check:

- [x] FTS-индекс расширен типами `learning`, `chat`, `mail`;
- [x] обучение/чат/почта индексируются и инвалидируются при изменении;
- [x] фильтры типа и периода 7/30 дней (тип — в SQL до `LIMIT`, дата —
  без обрезки выдачи);
- [x] переход из результата в соответствующий раздел;
- [x] экран аналитики: задачи, обучение, заметки/идеи/почта, финансы, топ
  расходов;
- [x] чистая функция аналитики с тестом;
- [x] без миграций и новых зависимостей.

## Что реализовано

- `lib/data/search/search_index.dart`:
  - `SearchEntityTypes.learning/chat/mail`;
  - `indexLearningTrack`, `indexChatThread`, `indexMailMessage`;
  - rebuild для новых типов; `removeSearchEntries` для удаления пакета;
  - версия индекса `search.index.version` и однократный backfill
    `ensureSearchIndexVersion` в `appDatabaseProvider`.
- `lib/data/repositories/search_repository.dart`:
  - фильтры `types`, `from`, `to`;
  - `SearchHit.occurredAt` (updatedAt/date/receivedAt).
- Репозитории обучения/чата/почты обновляют FTS при create/update/delete/
  privacy.
- `lib/features/search/presentation/search_screen.dart`: chips типов, период,
  счётчик, переход по типу.
- `lib/features/analytics/domain/analytics_summary.dart` — чистая сводка.
- `lib/features/analytics/presentation/analytics_screen.dart` — экран
  `/analytics`; кнопка на дашборде.
- ARB RU/EN: типы поиска, фильтры, аналитика.

## Схема БД и бэкап

- Схема **v8** не меняется; миграций нет.
- При открытии существующей БД `ensureSearchIndexVersion` однократно
  перестраивает индекс (новые типы появляются без миграции схемы).
- Backup вызывает `rebuildSearchIndex` после импорта; чат в backup пока не
  входит (ограничение зафиксировано ниже).

## Тесты

- `test/search_repository_test.dart` — глобальный индекс обучения, чата,
  почты; существующие FTS-тесты.
- `test/analytics_summary_test.dart` — задачи/сессии/финансы/топ расходов.
- `test/analytics_screen_test.dart` — widget-тест экрана аналитики.
- `test/mail_repository_test.dart` — `countMessages` и privacy.
- Итог: **241/241**, analyze 0, Windows debug build success.

## Известные ограничения

- Вложения не индексируются: модуль вложений пока не реализован.
- Для заметок/задач/треков/чата фильтр даты использует `updatedAt`, для
  финансов — дату операции, для почты — `receivedAt`; это не единая
  «дата создания».
- Аналитика считает только валюту `FinanceDraft.defaultCurrency` (RUB) и
  явно подписывает её; операции в других валютах не входят. Приватность не
  фильтруется — это локальная сводка, не LLM-контекст.
- Фильтра по тегам в UI пока нет (теги находятся как текст); это ограничение
  stage-08, не блокер.
- Поиск по чату индексирует тред целиком; отдельные сообщения не являются
  отдельными результатами.
- Live-проверка UI/данных не выполнялась.

## Как проверить

```powershell
$env:Path += ";C:\src\flutter\bin"
flutter pub get
flutter gen-l10n
flutter analyze --fatal-infos
flutter test
flutter build windows --debug
```

Поиск: раздел «Поиск» → ввести запрос → выбрать типы/период.
Аналитика: дашборд → иконка аналитики.

## Ссылки

- ADR-025.
- Первое ревью A/B: [reviews/stage-08-review.md](../reviews/stage-08-review.md)
  — **FAIL**.
- Финальное ревью A/B:
  [reviews/stage-08-final-review.md](../reviews/stage-08-final-review.md) —
  **PASS WITH COMMENTS (0 MAJOR)**.
- Исправления: [reviews/stage-08-fix-results.md](../reviews/stage-08-fix-results.md).
- Предыдущий этап: [stage-07.md](stage-07.md).
