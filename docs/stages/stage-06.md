# Stage-06 — Почта

- **Дата:** 2026-11-16
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **fixes ready**, ожидается финальное независимое ревью.
  Первое и повторное ревью A/B — **FAIL** (см.
  [reviews/stage-06-review.md](../reviews/stage-06-review.md),
  [reviews/stage-06-re-review.md](../reviews/stage-06-re-review.md));
  блокеры обоих кругов исправлены (см.
  [reviews/stage-06-fix-results.md](../reviews/stage-06-fix-results.md)).
  Гейты: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **228/228**, `flutter build windows --debug` — success; CI
  `43923720070` (`83ece84`) — success, оба job'а.
- **Предыдущий этап:** stage-05 — **PASS WITH COMMENTS**, stage-06
  разблокирован.
- **Схема БД:** **v8** (`mail_accounts`, `mail_messages`).
- **ADR:** ADR-023.

## Цель и критерии приёмки

По `PROMPT.md`, модуль почты:

- подключение нескольких ящиков Gmail / Yandex Mail / Mail.ru **только через
  OAuth 2.0**, без IMAP;
- просмотр, поиск, суммаризация письма/треда через LLM;
- создание задачи из письма;
- флаг приватности на уровне ящика/письма; приватные письма не уходят в LLM;
  переключение приватности ящика применяется к уже сохранённым письмам;
- refresh-токены только в secure storage.

Критерии self-check:

- [x] OAuth 2.0 Authorization Code + PKCE, loopback callback;
- [x] токены в secure storage, в БД только `secret_ref`;
- [x] Gmail API adapter (list/get, MIME-текст);
- [x] Yandex 360 Mail API (официальный REST, scope `mail:messages.read`);
- [ ] Mail.ru: официального REST-чтения писем нет, IMAP запрещён; провайдер
  отключён в UI и задокументирован как внешнее ограничение;
- [x] локальный кэш писем и Unicode-поиск;
- [x] суммаризация через LLM с privacy fail-closed;
- [x] создание задачи из письма (тело не копируется, задача private);
- [x] UI подключения/синхронизации/просмотра/поиска и per-message privacy;
- [x] схема v8 и миграция v7→v8.

## Что реализовано

- `lib/features/mail/domain/mail_provider_type.dart` — провайдеры, OAuth
  endpoints, scopes, redirect URI, API base.
- `mail_account.dart`, `mail_message.dart`, `mail_repository.dart` — модели и
  контракт.
- `lib/data/repositories/mail_repository.dart` — аккаунты, стабильный upsert,
  Unicode-поиск, privacy ящика/письма, уникальность ящика, каскадное удаление,
  secretRef.
- `lib/features/mail/application/mail_oauth.dart` — PKCE, authorization URL,
  обмен code, refresh, optional `client_secret` (только secure storage),
  timeout, обработка 401/invalid grant, `MailTokenStore`, loopback callback.
- Запуск браузера на Windows через `rundll32` (без `cmd`), чтобы URL с `&`
  не обрезался.
- `lib/features/mail/data/mail_provider.dart` — Gmail API adapter,
  Yandex 360 Mail API (`folders/1/envelopes` + `messages/{id}/text-parts`;
  контракт:
  [envelopes](https://yandex.ru/dev/yandex-360/mail/ru/api/folders/get-envelopes.md),
  [text-parts](https://yandex.ru/dev/yandex-360/mail/ru/api/messages/get-text-parts.md)),
  Mail.ru отключён.
- `mail_sync_service.dart` — ensure token → fetch → upsert; 401 → refresh →
  один повтор.
- `mail_summary_service.dart` — суммаризация через default LLM; приватное
  письмо не отправляется.
- `lib/features/integrations/presentation/integrations_screen.dart` — UI почты.
- `lib/app/di.dart` — repository/OAuth/sync/summary providers.
- JSON-бэкап **v3** включает `mail_accounts`/`mail_messages`; токены в бэкап
  не попадают (они остаются в secure storage; после restore требуется
  повторная авторизация).
- Схема **v8**, миграция, индексы; ARB RU/EN.

## Контракты и интерфейсы

- `MailRepository`: list/get/create/update/delete аккаунтов;
  list/get/upsert/delete/updateMessagePrivacy писем.
- `MailOAuthService`: `connect`, `buildAuthorizationUrl`, `exchangeCode`,
  `refresh`, `forceRefresh`, `ensureToken`, `storeTokens`, `deleteTokens`.
- `MailProvider`: `fetchMessages(account, tokens, query, limit)`.
- `MailSyncService.sync(account)`.
- `MailSummaryService.summarizeMessage/summarizeMessages`.

## Схема БД на конец этапа

Схема **v8**:

- `mail_accounts`: id, provider_type, email, display_name, client_id,
  secret_ref, is_private_for_llm, created_at, updated_at.
- `mail_messages`: id, account_id FK cascade, remote_id, thread_id, from,
  subject, snippet, body, received_at, is_private_for_llm, created_at.
- Индексы: `idx_mail_accounts_provider`,
  unique `idx_mail_accounts_provider_email(provider_type, email)`,
  `idx_mail_messages_account_received`,
  unique `idx_mail_messages_account_remote(account_id, remote_id)`.
  Unique-индексы создаются в `onCreate`/`onUpgrade`; `beforeOpen` для
  legacy-v8 создаёт только non-unique индексы, чтобы не падать на дублях.
- Миграция `v7 → v8`: создаёт таблицы/индексы, сохраняет данные. Guard
  `from > to || from > 8 || to > 8`.

## Зависимости, добавленные на этапе

- `crypto: ^3.0.7` — SHA-256 для PKCE S256.

## Тесты

- `test/mail_repository_test.dart` — аккаунты, secretRef, stable upsert,
  Unicode-поиск, per-message privacy, дубликаты, каскад, валидация.
- `test/mail_oauth_test.dart` — PKCE URL, connect/state/PKCE, Windows
  command, обмен code, client secret, refresh, token store, token retry,
  invalid refresh, state mismatch, disabled Mail.ru.
- `test/mail_provider_test.dart` — Gmail list/get, MIME-декодирование,
  Yandex envelopes/text-parts, private propagation.
- `test/mail_sync_service_test.dart` — fake и реальный Gmail provider:
  401 → refresh → retry.
- `test/mail_summary_test.dart` — LLM-суммаризация и private fail-closed.
- `test/integrations_screen_widget_test.dart` — пустое состояние, аккаунт,
  поиск с сохранением ввода, task-from-mail private без тела.
- `test/backup_service_test.dart` — почта в v3, реальные токены не попадают.
- `test/db_migration_test.dart` — v7→v8, индексы, безопасное открытие v8 с
  дублями, guard v2→v9.

Итог: **228/228** тестов, analyze 0, Windows debug build success.

## Известные ограничения и техдолг

- Реальные OAuth-приложения/redirect URI не регистрировались; живые запросы
  и ручной GUI-smoke не выполнялись. Gmail — по официальному API; Yandex —
  по официальному Yandex 360 Mail API (нужен тариф 360 и live-smoke).
- Mail.ru отключён: официальный REST-API чтения писем отсутствует, а IMAP
  запрещён PROMPT. Это внешнее ограничение, а не заглушка.
- OAuth callback слушает фиксированный `127.0.0.1:53682`; этот redirect URI
  должен быть зарегистрирован в OAuth-приложении.
- JSON-бэкап v3 включает обучение и почту, но не включает чат, LLM-конфиги,
  аудит и настройки — pre-existing ограничение ADR-014. OAuth-токены в бэкап
  не входят.
- Тело письма хранится в локальной БД открыто, как остальные данные;
  шифрование полей — отдельный этап.
- Поиск по почте локальный (Unicode-фильтрация по последним 5000 письмам),
  без FTS/глобального поиска; Yandex API не имеет серверного поиска, query
  фильтрует страницу.
- `summarize_mail_mock` из stage-04 остаётся для tool-сценария; UI
  использует реальный `MailSummaryService`.
- Создание задачи из письма использует локальные данные; вложения не
  поддерживаются.

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

В приложении: «Интеграции» → «Подключить ящик» → выбрать провайдера, ввести
email, OAuth client ID (и client secret, если провайдер требует),
зарегистрировать показанный redirect URI → завершить вход в браузере →
синхронизировать → открыть письмо → «Суммаризировать» или «Создать задачу».

## Ссылки

- ADR-023.
- Первое ревью A/B: [reviews/stage-06-review.md](../reviews/stage-06-review.md)
  — **FAIL**.
- Повторное ревью A/B: [reviews/stage-06-re-review.md](../reviews/stage-06-re-review.md)
  — **FAIL**.
- Исправления: [reviews/stage-06-fix-results.md](../reviews/stage-06-fix-results.md).
