# Stage-06 — Почта

- **Дата:** 2026-11-16
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **done (self-check)**. Независимое ревью ещё не проводилось.
  Гейты: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **210/210**, `flutter build windows --debug` — success.
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
- [x] REST-адаптер для Yandex/Mail.ru (требует live-проверки контракта);
- [x] локальный кэш писем и поиск;
- [x] суммаризация через LLM с privacy fail-closed;
- [x] создание задачи из письма;
- [x] UI подключения/синхронизации/просмотра/поиска;
- [x] схема v8 и миграция v7→v8.

## Что реализовано

- `lib/features/mail/domain/mail_provider_type.dart` — провайдеры, OAuth
  endpoints, scopes, redirect URI, API base.
- `mail_account.dart`, `mail_message.dart`, `mail_repository.dart` — модели и
  контракт.
- `lib/data/repositories/mail_repository.dart` — аккаунты, upsert писем,
  поиск, privacy, каскадное удаление, secretRef.
- `lib/features/mail/application/mail_oauth.dart` — PKCE, authorization URL,
  обмен code, refresh, `MailTokenStore`, loopback callback.
- `lib/features/mail/data/mail_provider.dart` — Gmail API adapter и
  REST-адаптер Yandex/Mail.ru.
- `mail_sync_service.dart` — ensure token → fetch → upsert.
- `mail_summary_service.dart` — суммаризация через default LLM; приватное
  письмо не отправляется.
- `lib/features/integrations/presentation/integrations_screen.dart` — UI почты.
- `lib/app/di.dart` — repository/OAuth/sync/summary providers.
- JSON-бэкап **v3** включает `mail_accounts`/`mail_messages`; токены в бэкап
  не попадают (они остаются в secure storage; после restore требуется
  повторная авторизация).
- Схема **v8**, миграция, индексы; ARB RU/EN.

## Контракты и интерфейсы

- `MailRepository`: list/get/create/update/delete аккаунтов; list/get/upsert/
  delete писем.
- `MailOAuthService`: `connect`, `buildAuthorizationUrl`, `exchangeCode`,
  `refresh`, `ensureToken`, `storeTokens`, `deleteTokens`.
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
  `idx_mail_messages_account_received`,
  unique `idx_mail_messages_account_remote(account_id, remote_id)`.
- Миграция `v7 → v8`: создаёт таблицы/индексы, сохраняет данные. Guard
  `from > to || from > 8 || to > 8`.

## Зависимости, добавленные на этапе

- `crypto: ^3.0.7` — SHA-256 для PKCE S256.

## Тесты

- `test/mail_repository_test.dart` — аккаунты, secretRef, upsert/поиск,
  privacy, каскад, валидация.
- `test/mail_oauth_test.dart` — PKCE URL, обмен code, refresh, token store,
  отсутствие тела ошибки в результате.
- `test/mail_provider_test.dart` — Gmail list/get, MIME-декодирование.
- `test/mail_summary_test.dart` — LLM-суммаризация и private fail-closed.
- `test/integrations_screen_widget_test.dart` — пустое состояние и аккаунт.
- `test/db_migration_test.dart` — v7→v8, обновлены проверки v1→v8/v2→v8/
  v3→v8/v4→v8/v5→v8/v6→v8, guard v2→v9.

Итог: **210/210** тестов, analyze 0, Windows debug build success.

## Известные ограничения и техдолг

- Реальные OAuth-приложения/redirect URI у Gmail, Yandex и Mail.ru не
  регистрировались; живые запросы и ручной GUI-smoke не выполнялись.
  Gmail-адаптер реализован по официальному API; Yandex/Mail.ru используют
  REST-контракт `/messages?limit=&q=`, который требует проверки на живых
  API.
- OAuth callback слушает фиксированный `127.0.0.1:53682`; этот redirect URI
  должен быть зарегистрирован в OAuth-приложении.
- JSON-бэкап v3 включает обучение и почту, но не включает чат, LLM-конфиги,
  аудит и настройки — pre-existing ограничение ADR-014. OAuth-токены в бэкап
  не входят.
- Тело письма хранится в локальной БД открыто, как остальные данные;
  шифрование полей — отдельный этап.
- Поиск по почте локальный (SQL LIKE), без FTS/глобального поиска.
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
email и OAuth client ID → завершить вход в браузере → синхронизировать →
открыть письмо → «Суммаризировать» или «Создать задачу».

## Ссылки

- ADR-023.
- Ревью: будет добавлено в `docs/reviews/stage-06-review.md` после
  независимой проверки.
