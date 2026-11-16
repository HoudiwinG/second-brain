# Re-review: Stage-06 (почта)

- **Дата:** 2026-11-16
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `f568f17`
- **Предыдущее ревью:** [stage-06-review.md](stage-06-review.md) — FAIL на
  `2c377a6`.
- **Исправления первого круга:** [stage-06-fix-results.md](stage-06-fix-results.md).

## Итог

- **Reviewer A: FAIL.** 0 critical, **3 major**, 7 minor, 2 nit.
- **Reviewer B: FAIL.** 0 critical, **3 major**, 6 minor, 4 nit.
- **Объединённый вердикт: FAIL.** Блокеры:
  - `S06R-A-001` — 401-refresh-retry не работает, потому что реальные
    провайдеры выбрасывают `NetworkException`, а `MailSyncService` ждёт
    `Result.failure`.
  - `S06R-A-002` / `S06R-B-001` — Yandex-контракт не подтверждён ссылкой на
    публичную документацию; тест мокает собственные предположения.
  - `S06R-A-003` / `S06R-B-003` — unique index `(provider_type,email)`
    создаётся в `beforeOpen` без bump'а схемы; dev-БД с дублями может не
    открыться.
  - `S06R-B-002` — нет UI повторной авторизации/переподключения после
    restore/revoke.
- **Гейты:** A — analyze 0, test 218/218; B — analyze 0, CI
  `43917095617` (`f568f17`) success, 218/218.

## Статус блокеров первого ревью

| ID | Статус | Комментарий |
|---|---|---|
| S06-A-001 / S06-B-001 — Windows URL | fixed | `rundll32`, полный URL, тест |
| S06-A-008 / S06-B-002 — поиск | fixed | поле вне FutureBuilder, debounce, тест |
| S06-A-002/A-003 / S06-B-003 — провайдеры | partial | Mail.ru честно disabled; Yandex переведён, но контракт не подтверждён ссылкой |
| S06-A-004/A-005 — privacy/task | partial | per-message privacy есть; task не копирует body, но копирует snippet |
| S06-A-006/A-007 — OAuth robustness | partial | timeout/rotation есть; 401 не достижим, нет retry/invalid_grant UX |
| S06-A-009 / S06-B-004… — repository/data | fixed, новый дефект | stable upsert/Unicode/unique есть; unique в beforeOpen опасен |
| S06-A-010 / S06-B-… — тесты | partial | connect/PKCE есть; 401-тест ложноположительный, state/invalid_grant не покрыты |

## Ключевые новые находки

### [MAJOR] S06R-A-001 — 401-retry не работает

- **Где:** `mail_provider.dart` (`.when(failure: throw error)`),
  `mail_sync_service.dart:38-52`.
- **Что не так:** провайдер выбрасывает исключение вместо возврата
  `Result.failure`; ветка refresh/retry недостижима.
- **Исправление:** провайдеры возвращают `Failure`; добавлен тест с реальным
  `GmailMailProvider` и MockClient.

### [MAJOR] S06R-A-002 / S06R-B-001 — Yandex

- **Где:** `mail_provider_type.dart`, `mail_provider.dart`, docs/ADR.
- **Что не так:** не было ссылки на официальный контракт; B проверял
  `api360` (админ-API), а не `yandex-360/mail`.
- **Исправление:** добавлены прямые ссылки на
  `yandex-360/mail/.../get-envelopes.md` и `get-text-parts.md` в коде, ADR и
  отчёте. Live-smoke всё ещё не выполнялся.

### [MAJOR] S06R-A-003 / S06R-B-003 — unique index

- **Где:** `app_database.dart` — `beforeOpen` → `_createMailIndexes`.
- **Что не так:** existing v8 DB с дублями могла упасть на
  `CREATE UNIQUE INDEX`.
- **Исправление:** `beforeOpen` создаёт индексы с
  `includeUniqueAccount: false`; unique создаётся только в
  onCreate/onUpgrade. Добавлен тест открытия v8-базы с дублями.

### [MAJOR] S06R-B-002 — re-auth

- **Где:** UI интеграций, `createAccount`.
- **Что не так:** после restore/revoke нет повторной авторизации; удаление
  аккаунта стирает кэш; connect на существующем ящике выбрасывал токены.
- **Исправление:** кнопка «Авторизоваться заново», переиспользование
  существующего аккаунта в `_connect`, сохранение кэша.

### [MINOR] S06R-A-004 / B-011 — task snippet

- **Исправление:** task-from-mail больше не копирует snippet/body; тест
  проверяет private и отсутствие текста.

### [MINOR] S06R-A-005 / B-004 — token endpoint

- **Исправление:** retry после 5xx, timeout, удаление токенов при
  invalid_grant/401/403; тесты.

### [MINOR] S06R-A-006 / B-007 — backup

- **Исправление:** тест записывает реальные токены/client_secret в
  `SecretStore` и проверяет их отсутствие в JSON.

### [MINOR] S06R-A-007 / B-013 — stable upsert / Unicode

- **Исправление:** тесты сравнивают id/created_at и ищут «счёт» по «Счёт».

### [MINOR] S06R-A-008 / B-006 — поиск 500

- **Исправление:** лимит увеличен до 5000 последних писем; ограничение
  задокументировано. FTS/полный скан остаётся техдолгом.

### Остаточные (не блокеры)

- mock `summarize_mail` tool;
- суммаризация только письма, не треда;
- 5000-лимит поиска;
- global `_syncing`/OAuth progress;
- revoke endpoint и очистка старых секретов при restore;
- live OAuth/Yandex smoke.

## Соответствие критериям

- [x] OAuth 2.0 + PKCE/state/loopback (state mismatch покрыт тестом).
- [x] Tokens only in secure storage, `secret_ref` in DB.
- [x] Gmail.
- [x] Yandex 360 Mail API with contract links (live not performed).
- [ ] Mail.ru: external limitation, disabled.
- [x] View/search/summary/task, privacy account+message.
- [x] Re-auth existing account.
- [x] Schema v8, v7→v8, safe beforeOpen.
- [x] Backup v3 without tokens.
- [x] Analyze 0, tests 225/225, Windows build.

## Метод и ограничения

- Read-only; live OAuth/API и GUI-smoke не выполнялись.
- A запускал analyze/test; B проверял CI и публичную документацию.
