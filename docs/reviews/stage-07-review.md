# Review: Stage-07 (поиск идей)

- **Дата:** 2026-11-17
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `a537265`
- **Отчёт:** [stages/stage-07.md](../stages/stage-07.md)
- **ADR:** ADR-024

## Итог

- **Reviewer A: FAIL.** 0 critical, **1 major**, 12 minor, 6 nit.
- **Reviewer B: FAIL.** 0 critical, **1 major**, 9 minor, 7 nit.
- **Объединённый вердикт: FAIL.** Блокер — агрегатор статей отдаёт
  `limit` каждому провайдеру и затем делает `take(limit)`, поэтому Crossref
  (первый в DI) вытесняет Hacker News. «Блогерская» половина модуля
  фактически недоступна в UI.
- **Гейты:** A — analyze 0, test 234/234; B — CI `44018421649` (`a537265`)
  success, 234/234.

## Блокер

### [MAJOR] S07-A-001 / S07-B-001 — Hacker News вытесняется Crossref

- **Где:** `article_search_providers.dart` (`provider.search(limit: limit)`,
  `merged.take(limit)`), `idea_search_dialog.dart` (`search(text)` → 10),
  `di.dart` (Crossref, затем HN).
- **Что не так:** каждый провайдер возвращает до `limit`, объединение
  обрезается тем же `limit`; 10 статей Crossref занимают весь бюджет.
- **Тест не ловит:** фейки дают 3/1 при limit=10.
- **Исправление:** round-robin по провайдерам + тест «10 + 1 → оба источника
  присутствуют».

## Ключевые неблокирующие находки

- Список идей не обновляется после сохранения из диалога.
- Вкладки без подписей, ARB-ключи `ideasSearchArticles/Images` не
  используются.
- Error показывается только при отказе обоих сервисов; partial failure и
  loading/empty состояния неполные.
- `Image.network` обходит `ApiClient`.
- Нет polite User-Agent/учёта `Retry-After`; rate limits не задокументированы.
- HTML/JATS-сущности в Crossref/HN не декодируются.
- Пустые `imageUrl`/URL не фильтруются; атрибуция изображения неполная.
- Сохранение картинки в заметку — сырой markdown, который не рендерится.
- Нет защиты от двойного сохранения/дубликатов.
- Тесты не покрывают отказы, лимиты, сохранение в заметку и изображения.

## Соответствие критериям

- [x] Crossref (наука) + Hacker News (блоги) реализованы.
- [ ] Оба источника фактически доступны в UI — блокер.
- [x] Openverse, `ImageSearchProvider`.
- [x] Сохранение в `IdeaEntry`/`Note`.
- [~] UI: вкладки, loading/empty/error — частично.
- [~] Все сетевые вызовы через `ApiClient` — `Image.network` (позже убран).
- [x] ARB RU/EN.
- [x] Analyze 0, 234/234, CI success; документация обновлена.

## Расхождения документации с кодом

- ADR-024 говорил, что rate limits «задокументированы», хотя значений нет.
- Stage-07 говорил о вкладках «Статьи/Изображения», но они были только с
  иконками.
- Stage-07 заявлял полное покрытие `ApiClient`, но превью использовало
  `Image.network`.
- ADR-024: источник изображения — страница, но идея сохраняла `imageUrl`.

## Метод и ограничения

- Read-only; live API не выполнялись.
- A запускал analyze/test; B проверял CI/analyze.
