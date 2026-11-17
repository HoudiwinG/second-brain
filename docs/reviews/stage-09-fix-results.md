# Stage-09 — результаты исправлений после FAIL-ревью

- **Дата:** 2026-11-17
- **Исходное ревью:** [stage-09-review.md](stage-09-review.md)
- **Состояние до исправлений:** `234fc29`
- **Статус:** исправления готовы, ожидается повторное ревью.

## Блокеры

### S09-B-001 — MSVC runtime в installer

- `tool/build_installer.ps1` скачивает `vc_redist.x64.exe` (если файла нет).
- `installer/second_brain.iss`:
  - `[Files]` включает redist только при `NeedsVCRedist`;
  - `[Run]` ставит его тихо `/install /quiet /norestart`;
  - `[Code]` проверяет registry
    `SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64`.
- Файл redist в git не хранится (`.gitignore`).
- CI installer теперь ~36 MB; artifact
  `SecondBrain-1.0.0-setup.exe` 36 270 862 B.

### S09-B-002 — performance/тесты

- `test/performance_smoke_test.dart`: 1000 заметок, batch insert,
  rebuild, FTS; локально `insert=126 ms`, `rebuild=666 ms`, `fts=7 ms`.
- `test/release_packaging_test.dart`: обязательные installer/CI шаги.
- `docs/PERFORMANCE.md` — методика, результаты, узкие места.
- Итог: **243/243**.

## Неблокирующие исправления/фиксация

- README: «реализация MVP завершена, ожидается ревью stage-09».
- `docs/RELEASE.md`: prereq Inno ≥6.3, redist не в git, checksum.
- ADR-026: VC redist, artifact.
- Версия/CI: `f09349c`, run `44122513044`, artifact hash
  `064C8C98…020C8F`.
- Установочный smoke/upgrade и подпись остаются ручными/техдолгом.

## Гейты

```text
flutter analyze --fatal-infos       0 issues
flutter test                        243/243 passed
flutter build windows --debug       success
flutter build windows --release     success
CI 44122513044 (f09349c)            success, installer artifact 36 270 862 B
```
