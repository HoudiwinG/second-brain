# Performance smoke (MVP)

Минимальный perf-проход stage-09. Цель — зафиксировать измеримую базу и не
допустить очевидных регрессий, а не полноценный бенчмарк-фреймворк.

## Методика
`test/performance_smoke_test.dart`:
- in-memory SQLite (Drift);
- 1000 заметок с общим словом `needle`;
- пакетная вставка;
- полный `rebuildSearchIndex`;
- FTS-запрос `needle` с лимитом 50.

Тест печатает `PERF ...` в CI-лог и проверяет корректность выдачи; жёсткие
миллисекундные пороги не ставятся, потому что Windows/Linux-раннеры и
debug/test JIT различаются.

## Локальный результат (2026-11-17, Windows, Flutter 3.47.7, test/JIT)
```text
notes_insert_ms=126
index_rebuild_ms=666
fts_query_ms=7
hits=50
```
Это порядок величин для MVP; release/AOT и реальные профили пользователя
могут отличаться.

## Известные узкие места
- Полный rebuild индекса на старте после обновления (одноразово) и при
  изменении тегов — линейный по количеству сущностей.
- Дата-фильтр поиска вычисляет `occurredAt` отдельными запросами (N+1),
  но ограничен `limit`; оптимизация — техдолг.
- Аналитика загружает локальные списки и сессии по каждому треку (N+1).
- Изображения в поиске идей показываются без встроенного кэша.

## Что проверено
- `flutter analyze --fatal-infos` — 0 issues.
- `flutter test` — 243/243 (включая perf-smoke и packaging-test).
- `flutter build windows --debug` / `--release` — success.
- CI `build-windows` собирает release + installer.
