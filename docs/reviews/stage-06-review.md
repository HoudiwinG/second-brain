# Review: Stage-06 (почта)

- **Дата:** 2026-11-16
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `2c377a6` (код stage-06 — `049c85e`,
  backup — `6cd2195`, privacy — `2c377a6`)
- **Отчёт разработчика:** [stages/stage-06.md](../stages/stage-06.md)
- **ADR:** ADR-023

## Итог

- **Reviewer A: FAIL.** 1 critical, **8 major**, 8 minor, 1 nit.
- **Reviewer B: FAIL.** 0 critical, **3 major**, 12 minor, 2 nit.
- **Объединённый вердикт: FAIL.** Блокеры — OAuth-подключение на Windows,
  нерабочий поиск, неподтверждённые Yandex/Mail.ru API, неполная privacy-модель
  и отсутствие обязательных OAuth/sync-тестов.
- **Гейты:** reviewer A — analyze 0, test **210/210**. Reviewer B — analyze 0,
  CI `43910673182` (`2c377a6`) success (оба job'а, 210/210). Windows build
  локально не перепроверялся из-за параллельного ревью.

## Блокеры

| ID | Severity | Проблема |
|----|----------|----------|
| S06-A-001 / S06-B-001 | CRITICAL/MAJOR | `cmd /c start` обрезает authorization URL по `&`; подключение ящика на Windows не работает. |
| S06-A-008 / S06-B-002 | MAJOR | `TextField` поиска в `FutureBuilder` пересоздаётся на каждом символе; ввод/фокус теряются. |
| S06-A-002 / S06-A-003 / S06-B-003 | MAJOR | Yandex/Mail.ru endpoints/scopes не подтверждены; `mail:imap:read` противоречит OAuth-only; client secret не поддерживался; 2 из 3 провайдеров фактически заглушки. |
| S06-A-004 / S06-A-005 | MAJOR | Нет управления privacy на уровне письма; task-from-mail копирует тело и не защищён после включения privacy ящика. |
| S06-A-006 / S06-A-007 | MAJOR | Нет обработки revoke/invalid_grant/401 и повторной авторизации; token endpoint без timeout/retry; rotated refresh token терялся. |
| S06-A-009 / S06-B-004… | MAJOR/MINOR | Repository/data: `LIKE`/кириллица, `insertOrReplace` меняет id, дубликаты аккаунтов, backup/token policy, утечка `http.Client`. |
| S06-A-010 / S06-B-… | MAJOR/MINOR | Тесты не покрывают connect/state/PKCE, sync, Yandex REST, поиск в UI, per-message privacy, task privacy, отсутствие токенов в backup. |

## Ключевые находки

### [CRITICAL] S06-A-001 / [MAJOR] S06-B-001 — Windows OAuth URL

- **Где:** `lib/features/mail/application/mail_oauth.dart` —
  `_defaultBrowserLauncher`.
- **Что не так:** URL передавался в `cmd /c start`; `cmd` интерпретирует `&`
  как разделитель команд, поэтому браузер получал только часть query.
- **Ожидаемое:** браузер получает полный URL, включая `scope`, `state`,
  `code_challenge`.
- **Исправление:** запуск через `rundll32 url.dll,FileProtocolHandler` с URL
  одним аргументом; тест `browserCommand` проверяет полный URL.

### [MAJOR] S06-A-008 / S06-B-002 — поиск

- **Где:** `lib/features/integrations/presentation/integrations_screen.dart`.
- **Что не так:** `TextField` находился внутри `FutureBuilder`; каждый ввод
  запускал `_reload()`, FutureBuilder показывал spinner и уничтожал поле.
- **Исправление:** поле вынесено над FutureBuilder, добавлены controller и
  debounce 300 мс; тест проверяет сохранение текста и фильтрацию.

### [MAJOR] S06-A-002/S06-A-003/S06-B-003 — Yandex/Mail.ru

- **Где:** `mail_provider_type.dart`, `mail_provider.dart`.
- **Что не так:** Yandex scope был `mail:imap:read` (IMAP), endpoint —
  предположительный; Mail.ru REST чтения писем не подтверждён; client secret
  не передавался, хотя нужен части OAuth-клиентов.
- **Исправление:**
  - Yandex переведён на официальный Yandex 360 Mail API
    `https://cloud-api.yandex.net/v1/mail`, scope `mail:messages.read`,
    `Authorization: OAuth`, методы `folders/1/envelopes` и
    `messages/{id}/text-parts`.
  - Mail.ru отключён в UI (`available=false`): официальный Mail.ru API не
    предоставляет чтение писем; IMAP запрещён PROMPT.
  - OAuth поддерживает `client_secret`; он хранится только в secure storage
    вместе с токенами.

### [MAJOR] S06-A-004/S06-A-005 — privacy

- **Где:** `mail_repository.dart`, `integrations_screen.dart`.
- **Что не так:** нельзя было управлять флагом письма; task-from-mail копировал
  тело; выключение privacy ящика перезаписывало все флаги.
- **Исправление:** `updateMessagePrivacy`, переключатель в карточке письма;
  включение privacy ящика применяет флаг к кэшу, выключение не сбрасывает
  индивидуальные флаги; task-from-mail не копирует тело и всегда создаётся
  private.

### [MAJOR] S06-A-006/A-007 — OAuth robustness

- **Где:** `mail_oauth.dart`, `mail_sync_service.dart`.
- **Что не так:** не было timeout/retry token endpoint, обработки 401/invalid
  grant, сохранения rotated refresh token.
- **Исправление:** timeout 20 с, повторное использование refresh token,
  `forceRefresh` и один retry синхронизации после 401; ошибки 400/401/403
  трактуются как требование повторной авторизации.

### [MAJOR] S06-A-009 / S06-B-004… — repository/data

- **Исправлено:** upsert обновляет существующую строку (id/created_at
  стабильны); unique index `(provider_type, email)` и проверка дубликата;
  поиск фильтрует Unicode в Dart (кириллица); `http.Client` закрывается;
  backup v3 включает почту без токенов.

### [MAJOR] S06-A-010 / S06-B-… — тесты

Добавлены: `connect` с fake callback/launcher (state/PKCE), Windows command,
Yandex REST, sync с 401+refresh, per-message privacy, поиск в widget-тесте,
отсутствие токенов в backup. Итог на `2c377a6`: **210/210**.

## Соответствие критериям stage-06

- [x] OAuth 2.0 + PKCE, state, loopback callback.
- [x] Токены только в secure storage; в БД только `secret_ref`.
- [x] Gmail API.
- [x] Yandex 360 Mail API (официальный REST).
- [ ] Mail.ru: официальный REST чтения писем отсутствует; провайдер отключён.
- [x] Просмотр, локальный поиск, суммаризация, задача из письма.
- [x] Privacy на уровне ящика и письма.
- [x] Backup v3 без токенов.
- [x] Analyze 0, tests 210/210, Windows build.

## Расхождения документации с кодом (на момент ревью)

- Отчёт называл Yandex/Mail.ru «REST-адаптерами» без указания, что контракт
  не подтверждён.
- Отчёт не упоминал disabled Mail.ru и отсутствие client secret.
- Отчёт утверждал, что поиск работает, хотя поле теряло ввод.
- Отчёт не фиксировал ограничения Windows launcher и сценарии 401.

## Метод и ограничения

- Read-only ревью; живые OAuth/API-вызовы не выполнялись.
- Reviewer A запускал analyze/test; reviewer B проверял CI и analyze.
- Windows GUI-smoke не выполнялся.
