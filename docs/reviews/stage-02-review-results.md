# Результаты исправлений по ревью stage-02

- **Дата:** 2026-10-23
- **Автор:** agent-1 (DeepSeek V4.1 Flash Free, OpenCode)
- **Проверяемое состояние:** `master` @ `296970b`; исправления — код-коммит
  `8956179`
- **Источник находок:** [stage-02-review.md](stage-02-review.md) — вердикт
  **FAIL** (critical 0, major 2, minor 6, nit 0)
- **Статус:** все находки R02-001…R02-008 исправлены. Это self-check
  разработчика, а не повторное ревью: формальный вердикт в исходном файле
  остаётся **FAIL** до проверки agent-2.

## Что исправлено

| ID | Критичность | Исправление | Доказательства |
|----|-------------|-------------|----------------|
| R02-001 | MAJOR | Иконка трея на Windows берётся по абсолютному пути от `Platform.resolvedExecutable`: `<exe-dir>/data/flutter_assets/assets/tray_icon.ico`. Перед `trayManager.setIcon` проверяется `File.existsSync()`; `_trayReady = true` выставляется только после успешной установки иконки, меню и подсказки. | `lib/app/desktop_services.dart`, `test/desktop_services_test.dart`; smoke из каталога `.exe` (см. ниже) |
| R02-002 | MAJOR | `ReminderNotifier.show` возвращает `Future<bool>`; `LocalReminderNotifier` возвращает `false` при ошибке/недоступности WinToast; `ReminderScheduler` вызывает `markReminderSent` только при `true`, иначе повторяет попытку на следующем тике. | `test/reminder_scheduler_test.dart`: false и throwing notifier |
| R02-003 | MINOR | Применение сохранённого хоткея на старте ожидается. При `false` применяется `QuickHotkey.defaultBinding`, фактическая комбинация сохраняется в `app_settings`, состояние UI отражает реально зарегистрированное значение. Ранний `return true` при совпадении с state удалён, поэтому повторное применение возможно. | `test/settings_controller_test.dart`: startup-apply=false, fallback и запись |
| R02-004 | MINOR | Guard `from > to || from > 3 || to > 3` перенесён в начало `onUpgrade`, до любых DDL. Неподдерживаемый `v2 → v4` и downgrade `v4 → v3`/`v3 → v2` падают с `UnsupportedError`, не оставляя частичную миграцию и не перезаписывая `user_version`. | `test/db_migration_test.dart`: `v2 → v4`, `v4 → v3`, сохранность данных |
| R02-005 | MINOR | Верхняя граница финансового диапазона стала эксклюзивной: `[from, to)`, `isSmallerThanValue(to)`. Контракт `list`/`summary` задокументирован в интерфейсе. | `test/data_repositories_test.dart`: операция следующего месяца не входит в прошлый |
| R02-006 | MINOR | `QuickCaptureDialog._save` обёрнут в `try/catch/finally`: исключение провайдера/репозитория показывает локализованную ошибку и сбрасывает `_saving`; успешное закрытие диалога не вызывает `setState` после `pop`. | `test/quick_capture_dialog_test.dart`: падающий `NotesRepository` |
| R02-007 | MINOR | Добавлены regression-тесты на failing notifier, startup-apply=false, backup `reminderSentAt`, эксклюзивную границу месяца, `v2 → v4`, `v4 → v3`, ошибку quick capture и путь к иконке трея. | `flutter test` — 69/69 |
| R02-008 | MINOR | Границы локального дня/месяца вынесены в `dashboard_period.dart` и считаются календарными конструкторами `DateTime(year, month, day + 1)` / `DateTime(year, month + 1)`, а не `+ Duration(days: 1)`. | `test/dashboard_period_test.dart`; дашборд использует helper |

## Локальные проверки

Выполнено 2026-10-23 после исправлений (Flutter 3.47.7, Dart 3.13.5):

```powershell
flutter analyze --fatal-infos   # 0 issues
flutter test                    # 69/69 passed
flutter build windows --debug   # success
```

## Smoke close-to-tray после R02-001

Сборка запускалась с рабочим каталогом
`build\windows\x64\runner\Debug` (не из корня репозитория). Проверено:

- файл `data\flutter_assets\assets\tray_icon.ico` существует рядом с `.exe`;
- после `taskkill /PID <pid>` без `/F` (WM_CLOSE) процесс оставался жив
  минимум 3 секунды, то есть окно скрылось в трей, а не завершило приложение;
- затем процесс был остановлен принудительно, чтобы не оставлять фоновый
  экземпляр.

Визуально меню и иконка в overflow трея не проверялись. Повторный GUI-smoke
остаётся за независимым ревьюером.

## Ограничения

- Повторное ревью stage-02 не проводилось; stage-03 остаётся заблокированным
  до вердикта без MAJOR.
- DST-переход (23/25-часовые сутки) локально не воспроизводился: тест
  проверяет календарную семантику границ, но не смену часового пояса.
- CI-run для коммита `8956179` нужно проверить после push; приватный
  репозиторий не позволяет agent-1 независимо читать статус Actions без
  токена.
