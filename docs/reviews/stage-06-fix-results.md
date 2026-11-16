# Stage-06 — результаты исправлений после FAIL-ревью

- **Дата:** 2026-11-16
- **Исходное ревью:** [stage-06-review.md](stage-06-review.md)
- **Проверяемое состояние до исправлений:** `2c377a6`
- **Статус:** исправления первого и второго круга готовы, ожидается финальное
  независимое ревью.

## Блокеры

### S06-A-001 / S06-B-001 — Windows OAuth URL

- **Исправление:** `MailOAuthService._defaultBrowserLauncher` больше не
  использует `cmd /c start`; на Windows URL передаётся одним аргументом в
  `rundll32 url.dll,FileProtocolHandler`.
- **Тест:** `browserCommand` проверяет полный URL с `&b=2&c=3`; `connect`
  проверяет, что authorization URL содержит все query-параметры, state и
  challenge.
- **Файлы:** `mail_oauth.dart`, `test/mail_oauth_test.dart`.

### S06-A-008 / S06-B-002 — поиск

- **Исправление:** `TextField` вынесен из `FutureBuilder` в постоянную часть
  экрана; добавлены `TextEditingController` и debounce 300 мс. Ввод и фокус не
  уничтожаются при перезагрузке списка.
- **Тест:** widget-тест вводит «счёт», ждёт debounce и проверяет сохранение
  текста + фильтрацию писем.
- **Файлы:** `integrations_screen.dart`,
  `test/integrations_screen_widget_test.dart`.

### S06-A-002/S06-A-003/S06-B-003 — провайдеры

- **Yandex:** официальный Yandex 360 Mail API
  `https://cloud-api.yandex.net/v1/mail`; scope `mail:messages.read`;
  `Authorization: OAuth`; `GET /folders/1/envelopes` и
  `GET /messages/{id}/text-parts`.
- **Mail.ru:** официальный Mail.ru API не предоставляет REST-чтение писем;
  IMAP запрещён PROMPT. Провайдер `available=false`, отключён в UI, не
  выдаёт себя за рабочий. Это внешнее ограничение, требующее продуктового
  решения.
- **OAuth client secret:** добавлен optional `client_secret` для code/refresh;
  хранится только в secure storage вместе с токенами.
- **Тесты:** Yandex envelopes/text-parts, disabled Mail.ru, client secret в
  обмене code.
- **Файлы:** `mail_provider_type.dart`, `mail_provider.dart`,
  `mail_oauth.dart`, UI, тесты.

### S06-A-004/S06-A-005 — privacy

- **Исправление:** добавлен `MailRepository.updateMessagePrivacy` и
  переключатель в карточке письма. Включение privacy ящика применяет флаг к
  кэшу; выключение не сбрасывает индивидуальные флаги (fail-closed).
  Task-from-mail больше не копирует тело письма и всегда создаётся private.
- **Тесты:** per-message privacy, privacy ящика/кэша, сохранение флага после
  выключения ящика.
- **Файлы:** `mail_repository.dart`, `mail_repository.dart` (domain),
  `integrations_screen.dart`, тесты.

### S06-A-006/S06-A-007 — OAuth robustness

- **Исправление:** timeout 20 с для token endpoint; rotated refresh token
  сохраняется; `forceRefresh`; при 401 от API — refresh и один retry; ошибки
  400/401/403 трактуются как повторная авторизация.
- **Тест:** `MailSyncService` с fake provider: первый вызов 401, затем refresh
  и успешный retry; проверены новые access/refresh tokens.
- **Файлы:** `mail_oauth.dart`, `mail_sync_service.dart`,
  `test/mail_sync_service_test.dart`.

### S06-A-009 / S06-B-004… — repository/data

- **Исправлено:**
  - upsert обновляет существующую строку, сохраняя id/created_at;
  - unique index `(provider_type, email)` + проверка дубликата;
  - Unicode-поиск в Dart (кириллица);
  - `http.Client` закрывается после fetch;
  - backup v3 включает почту, токены не экспортируются.
- **Тесты:** дубликаты, повторный upsert, backup без токенов, миграция с
  новым индексом.

## Второй круг (после повторного ревью `f568f17`)

Повторное ревью A/B снова дало **FAIL** (см.
[stage-06-re-review.md](stage-06-re-review.md)). Исправлено:

- **401-retry:** провайдеры больше не выбрасывают `Result.failure` через
  `throw`; Gmail/Yandex возвращают `Failure`, поэтому `MailSyncService`
  действительно делает refresh + retry. Добавлен тест с реальным
  `GmailMailProvider` и `MockClient` (401 → refresh → 200).
- **Yandex:** добавлены прямые ссылки на официальный контракт Yandex 360
  Mail API в коде, ADR и отчёте.
- **Unique index:** `beforeOpen` больше не создаёт unique-индекс по
  аккаунтам; он создаётся только в `onCreate`/`onUpgrade`. Добавлен тест
  открытия v8-базы с дублями.
- **Re-auth:** добавлена кнопка «Авторизоваться заново» и повторное
  использование существующего аккаунта при connect; восстановленный backup
  можно переавторизовать без удаления кэша.
- **Token endpoint:** retry после 5xx, timeout; `invalid_grant`/401/403
  удаляют битые токены. Добавлены тесты retry, invalid refresh и state
  mismatch loopback.
- **Privacy/task:** task-from-mail больше не копирует snippet (только
  from/date), всегда private; summary перечитывает письмо из БД.
- **Тесты:** stable id/created_at, Unicode-регистр, task privacy, backup с
  реально записанными токенами, v8-дубли. Итог **228/228**.

Остаются не блокирующими: mock `summarize_mail` tool, суммаризация только
одного письма (не треда), ограничение поиска 5000 последних писем, UI
progress/global sync, revoke endpoint и очистка старых секретов при restore.

## Гейты после исправлений

```text
flutter analyze --fatal-infos       No issues found
flutter test                        228/228 passed
flutter build windows --debug       success
CI 43923720070 (83ece84)            success (analyze-and-test, build-windows)
```

## Остаточные ограничения

- Live OAuth/API smoke не выполнялся; Yandex 360 требует тариф.
- Mail.ru нельзя подключить без IMAP или официального REST API.
- JSON-бэкап v3 не содержит токены; после restore нужна повторная
  авторизация.
- Почта хранится локально в открытом виде, как остальные данные.
