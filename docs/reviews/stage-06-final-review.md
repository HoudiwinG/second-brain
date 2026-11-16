# Final review: Stage-06 (почта)

- **Дата:** 2026-11-16
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `1ad2caa` (после финальных правок —
  `228/228`), история: `2c377a6` FAIL, `f568f17` FAIL, `a9cb44b`/`1ad2caa`
  PASS WITH COMMENTS.
- **Отчёт:** [stages/stage-06.md](../stages/stage-06.md); ADR-023.

## Итог

- **Reviewer A: PASS WITH COMMENTS.** 0 critical, **0 major**, 2 minor, 2 nit
  после проверки исправлений.
- **Reviewer B: PASS WITH COMMENTS.** 0 critical, **0 major**, 3 minor, 1 nit
  после проверки исправлений.
- **Объединённый вердикт: PASS WITH COMMENTS.** Блокеров нет.
- **Гейты:** analyze 0; test **228/228**; CI `43927529327` (`1ad2caa`) —
  success, оба job'а (`analyze-and-test`, `build-windows`).

## Блокеры предыдущих ревью

Все CRITICAL/MAJOR закрыты:

- Windows OAuth URL — `rundll32`, полный URL, тест.
- Поиск — поле вне `FutureBuilder`, controller + debounce.
- Провайдеры — Gmail; официальный Yandex 360 Mail API; Mail.ru отключён.
- Privacy — ящик + письмо, fail-closed, task без body/snippet.
- OAuth robustness — `ApiClient`, timeout/retry, 401 → refresh → retry,
  rotated refresh, invalid_grant/401/403, re-auth UI.
- Gmail MIME — `multipart/alternative` выбирает plain, `multipart/mixed` не
  берёт вложения.
- Repository/DB — stable upsert, уникальность, Unicode-поиск, safe
  `beforeOpen`, backup v3 без токенов.
- Тесты — connect/state/PKCE, Windows command, Yandex REST, реальный Gmail
  401, per-message privacy, task privacy, backup tokens, v8 duplicate.

## Остаточные комментарии (не блокеры)

- Нет отдельного теста на дубли `(account_id, remote_id)` в `beforeOpen`.
- Не все UI-ключи ARB используются; OAuth progress/cancel отсутствует.
- Суммаризация только одного письма, не треда; mock `summarize_mail` tool.
- Поиск ограничен последними 5000 письмами.
- Live OAuth/API smoke и GUI-smoke не выполнялись; Yandex 360 требует тариф.
- `http.Client` создаётся в DI, но используется только как транспорт
  `ApiClient`.
- Legacy-v8 без unique-индексов остаётся безопасным за счёт проверок
  репозитория.

## Соответствие критериям

- [x] OAuth 2.0 Authorization Code + PKCE S256, state, loopback.
- [x] Токены только в secure storage, в БД только `secret_ref`.
- [x] Gmail API; официальный Yandex 360 Mail API.
- [ ] Mail.ru — внешнее ограничение: нет официального REST-чтения, IMAP
  запрещён; провайдер отключён.
- [x] Просмотр, локальный Unicode-поиск, суммаризация, задача из письма.
- [x] Privacy ящика/письма, fail-closed; task private без тела.
- [x] Re-auth без удаления кэша.
- [x] Схема v8, миграция v7→v8, safe `beforeOpen`.
- [x] Backup v3 с почтой без токенов.
- [x] Analyze 0, 228/228, Windows build.

## Метод и ограничения

- Read-only ревью; живые OAuth/API-вызовы и GUI-smoke не выполнялись.
- A запускал analyze/test локально; B проверял CI и analyze.
- Windows build подтверждён CI-job'ом `build-windows`.
