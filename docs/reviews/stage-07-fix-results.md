# Stage-07 — результаты исправлений после FAIL-ревью

- **Дата:** 2026-11-17
- **Исходное ревью:** [stage-07-review.md](stage-07-review.md)
- **Состояние до исправлений:** `a537265`
- **Статус:** финальное ревью A/B — **PASS WITH COMMENTS (0 MAJOR)**.

## Блокер

### S07-A-001 / S07-B-001 — HN вытесняется Crossref

- **Исправление:** `ArticleSearchService` собирает списки провайдеров и
  выдаёт результаты round-robin, а не `merged.take(limit)`. При 10 Crossref
  + 1 HN в выдаче есть оба источника.
- **Тест:** `test/idea_search_test.dart` — «не вытесняет второй источник
  лимитом».
- **Файлы:** `article_search_providers.dart`, `idea_search_test.dart`.

## Неблокирующие исправления

- Список идей перезагружается после закрытия диалога поиска.
- Вкладки получили текстовые подписи из ARB.
- Ошибка показывается при отказе любого из сервисов (partial failure виден).
- `Image.network` убран: превью не обходит `ApiClient`; изображение
  сохраняется ссылкой/атрибуцией.
- Добавлен `User-Agent: SecondBrain/1.0` для Crossref/HN/Openverse.
- HTML/JATS-сущности декодируются в Crossref/HN.
- Пустые URL изображений и статей отбрасываются.
- Источник идеи-изображения — `pageUrl ?? imageUrl`.
- Тело заметки без ведущих пустых строк.
- Enter во время поиска не запускает второй параллельный запрос.
- Тест пустого запроса считает обращения к MockClient.

## Остаточные ограничения

- Нет per-tab loading/cancel, пагинации, LLM-переранжирования.
- Rate limits публичных API не измерялись; `Retry-After` не учитывается.
- Атрибуция изображения без `license_url`/`license_version`.
- Нет локального скачивания/рендеринга изображений в заметках.
- Нет защиты от повторного сохранения одного результата.
- Live-smoke Crossref/HN/Openverse не выполнялся.

## Гейты

```text
flutter analyze --fatal-infos       0 issues
flutter test                        235/235 passed
flutter build windows --debug       success
```
