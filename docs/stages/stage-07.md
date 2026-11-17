# Stage-07 — Поиск идей

- **Дата:** 2026-11-17
- **Агент:** agent-1 (OpenCode)
- **Ветка:** `master`
- **Статус:** **fixes ready**, ожидается повторное ревью. Первое ревью A/B —
  **FAIL** (S07-A-001/S07-B-001: HN вытеснялся Crossref); блокер и
  неблокирующие замечания исправлены (см.
  [reviews/stage-07-fix-results.md](../reviews/stage-07-fix-results.md)).
  Гейты: `flutter analyze --fatal-infos` — 0 issues, `flutter test` —
  **235/235**, `flutter build windows --debug` — success.
- **Предыдущий этап:** stage-06 — **PASS WITH COMMENTS (0 MAJOR)**.
- **Схема БД:** **v8** без изменений.
- **ADR:** ADR-024.

## Цель и критерии приёмки

По `PROMPT.md`, модуль 7:

- поиск научных/блогерских статей (LLM web-search или специализированные
  API);
- подбор изображений по теме через `ImageSearchProvider` с первой
  реализацией;
- сохранение результатов в `IdeaEntry`/`Note`.

Критерии self-check:

- [x] статья: Crossref REST (наука) и Hacker News Algolia (блоги/техно);
- [x] изображения: Openverse, автор/лицензия/страница источника;
- [x] сохранение в идею и заметку через существующие репозитории;
- [x] UI поиска с вкладками и состояниями empty/error/loading;
- [x] все сетевые вызовы через `ApiClient`;
- [x] RU/EN ARB;
- [x] тесты провайдеров, агрегатора и widget-сценария сохранения.

## Что реализовано

- `lib/features/ideas/domain/idea_search.dart` — модели результатов и
  контракты `ArticleSearchProvider`/`ImageSearchProvider`.
- `lib/features/ideas/data/article_search_providers.dart`:
  - `CrossrefArticleSearchProvider` — `GET /works?query=&rows=`;
  - `HackerNewsArticleSearchProvider` — `GET /search?query=&tags=story`;
  - `ArticleSearchService` — объединение, дедупликация по URL, partial
    failure.
- `lib/features/ideas/data/image_search_providers.dart`:
  - `OpenverseImageSearchProvider` — `GET /images?q=&page_size=`;
  - `ImageSearchService`.
- `lib/features/ideas/presentation/idea_search_dialog.dart` — диалог поиска:
  запрос, вкладки «Статьи»/«Изображения», иконка/атрибуция изображения, кнопки
  «В идеи»/«В заметки».
- `lib/features/ideas/presentation/ideas_screen.dart` — action «Поиск идей».
- `lib/app/di.dart` — `articleSearchServiceProvider`,
  `imageSearchServiceProvider`.
- ARB RU/EN: `ideasSearch*`, `ideasSave*`.

## Контракты

- `ArticleSearchProvider.search(query,{limit})`.
- `ImageSearchProvider.search(query,{limit})`.
- `ArticleSearchService` / `ImageSearchService`.
- Сохранение: `IdeasRepository.create(IdeaDraft)` и
  `NotesRepository.create(NoteDraft)`; тег `idea-search`.

## Схема БД и бэкап

- Схема **v8** не меняется; миграций нет.
- JSON-бэкап не меняется: сохранённые результаты становятся обычными
  идеями/заметками и попадают в существующие разделы backup.

## Зависимости

Новых зависимостей нет. Используются существующие `http`/`ApiClient`.

## Тесты

- `test/idea_search_test.dart` — Crossref, Hacker News, Openverse,
  агрегация/дедупликация, пустой запрос.
- `test/idea_search_dialog_test.dart` — открытие диалога, поиск, сохранение
  статьи в идею (widget).
- Итог: **235/235**, analyze 0, Windows debug build success.

## Известные ограничения и техдолг

- Использованы специализированные публичные API, а не LLM web-search:
  единого web-search tool у всех LLM-провайдеров нет; результат LLM мог бы
  быть галлюцинацией. ADR-024.
- Live-запросы к Crossref/HN/Openverse не выполнялись; анонимные rate limits
  публичных API не измерялись.
- Пагинация — только первая страница; LLM-переранжирование и суммаризация
  статей не входят в этап.
- В MVP изображение сохраняется ссылкой/атрибуцией и показывается иконкой;
  встроенный просмотр/локальное скачивание — техдолг (сетевые вызовы не
  обходят `ApiClient`).
- Сохранённые результаты по умолчанию не private; пользователь может
  изменить флаг в редакторе идеи/заметки. Приватные исходные данные в поиск
  не отправляются.

## Как проверить

```powershell
$env:Path += ";C:\src\flutter\bin"
flutter pub get
flutter gen-l10n
flutter analyze --fatal-infos
flutter test
flutter build windows --debug
```

В приложении: «Идеи» → иконка поиска → запрос → вкладка статьи/изображения
→ «В идеи» или «В заметки».

## Ссылки

- ADR-024.
- Первое ревью A/B: [reviews/stage-07-review.md](../reviews/stage-07-review.md)
  — **FAIL**.
- Исправления: [reviews/stage-07-fix-results.md](../reviews/stage-07-fix-results.md).
- Предыдущий этап: [stage-06.md](stage-06.md).
