# Review: Stage-09 (полировка MVP)

- **Дата:** 2026-11-17
- **Ревьюеры:** independent reviewer A, independent reviewer B
- **Проверяемое состояние:** `master` @ `234fc29` (+ docs-правка CI)
- **Отчёт:** [stages/stage-09.md](../stages/stage-09.md)
- **ADR:** ADR-026

## Итог

- **Reviewer A: PASS WITH COMMENTS.** 0 critical, 0 major, 5 minor, 3 nit.
- **Reviewer B: FAIL.** 0 critical, **2 major**, 6 minor, 4 nit.
- **Объединённый вердикт: FAIL.**
- **Гейты:** analyze 0, test 241/241; CI `44119141513` (`234fc29`) success,
  installer artifact ~12 MB.

## Блокеры reviewer B

### S09-B-001 — installer без MSVC runtime

- `second_brain.exe`/plugin DLL импортируют `VCRUNTIME140.dll`,
  `MSVCP140.dll`; Release-каталог их не содержит, installer не ставит
  VC++ Redistributable. На чистой Windows приложение не запустится.
- **Исправление:** `vc_redist.x64.exe` скачивается build-скриптом,
  включается в `[Files]` и тихо ставится через `[Run]` при отсутствии
  runtime (проверка registry).

### S09-B-002 — performance/тесты этапа не выполнены

- Коммит не менял `lib/`/`test/`; 241 тест как на stage-08, нет perf-замеров.
- **Исправление:** `test/performance_smoke_test.dart` (1000 заметок:
  insert/rebuild/FTS), `test/release_packaging_test.dart`,
  `docs/PERFORMANCE.md` с локальными числами.

## Неблокирующие

- CI только компилирует installer, не устанавливает его.
- `-Configuration` в PS1 не влияет на ISS.
- Версия дублируется в pubspec/ISS/README.
- Нет AppMutex/close-to-tray update smoke.
- README «MVP завершён» vs «ревью ожидается».
- Отчёт stage-09 не по шаблону; навигация/ADR-список дрейфуют.
- Inno Setup ≥6.3 не закреплена.
- Нет checksum/подписи.

## Метод

- A: analyze/test, artifact inspection, PE imports.
- B: CI/artifact inspection, docs/code.
