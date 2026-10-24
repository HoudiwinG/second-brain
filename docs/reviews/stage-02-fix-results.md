# Stage-02 — результаты исправлений R02-009…R02-013

- **Дата (UTC):** 2026-10-24
- **Автор:** agent-1 (DeepSeek V4.1 Flash Free, OpenCode)
- **Источник задач:** [stage-02-fix-tasks.md](stage-02-fix-tasks.md), повторное
  ревью №2 в [stage-02-review.md](stage-02-review.md)
- **Состояние:** `master` @ `92a9642` (поверх `a50d972`, `8956179`, `82b04a2`)
- **Характер документа:** self-check разработчика и доказательства. Это **не
  вердикт ревью**. Ревью №3 (2026-10-24): **PASS WITH COMMENTS**; по пяти
  задачам R02-009…R02-013 открытых нет, добавлены не блокирующие комментарии
  R02-014/R02-015.

## Сводка

| ID | Критичность | Статус | Коммит |
|----|-------------|--------|--------|
| R02-009 | MAJOR | fixed (вариант A, ADR-017) | `a50d972` |
| R02-010 | MINOR | fixed | `a50d972` |
| R02-011 | MINOR | fixed | `92a9642` |
| R02-012 | NIT | fixed | `92a9642` |
| R02-013 | NIT | fixed | `92a9642` |

По задачам R02-009…R02-013 открытых MAJOR/MINOR/NIT не осталось; TD-27
переведён в `fixed`. Ревью №3 добавило не блокирующие комментарии R02-014
(MINOR, экран финансов) и R02-015 (NIT, лог retry).

## R02-009 — занятая глобальная комбинация (MAJOR)

**Что сделано (вариант A, рекомендованный ревьюером).**

- `hotkey_manager_windows 0.2.0` скопирован в
  `third_party/hotkey_manager_windows/`; изменения относительно upstream
  минимальны и описаны в `third_party/hotkey_manager_windows/PATCH.md`.
- В `windows/hotkey_manager_windows_plugin.cpp` результат
  `::RegisterHotKey(...)` проверяется. При `FALSE`:
  - возвращается `result->Error("hotkey_busy", "RegisterHotKey failed: …",
    GetLastError())`;
  - выполняется `return` **до** `hotkey_id_map_.insert`, чтобы не оставлять
    осиротевший id.
- В `pubspec.yaml` добавлен `dependency_overrides:
  hotkey_manager_windows: { path: third_party/hotkey_manager_windows }`;
  `pubspec.lock` обновлён.
- `third_party/**` исключён из `flutter analyze` в `analysis_options.yaml`
  (вендорный код не является частью Dart-дерева проекта).
- Откат в Dart вынесен из статического метода в тестируемый
  `DesktopServices.applyHotkeyBinding(binding, register:, unregisterAll:)`
  с typedef `HotkeyRegistrar`. `PlatformException` перехватывается,
  возвращается `false`; вызывающая сторона (`SettingsController`) уже
  откатывает state/сохранение и показывает `hotkeyBusyError`.
- Добавлен PowerShell-helper `tool/occupy_hotkey.ps1` для ручного сценария
  «комбинация занята».

**Файлы:** `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
`lib/app/desktop_services.dart`, `third_party/hotkey_manager_windows/**`,
`tool/occupy_hotkey.ps1`.

**Тесты:**

- `test/desktop_services_test.dart` — `applyHotkeyBinding` возвращает `false`
  при ошибке регистрации и восстанавливает прежнюю комбинацию;
- `test/desktop_services_test.dart` — в вендорном `.cpp` присутствует
  контракт `hotkey_busy` и проверка `RegisterHotKey`;
- `test/desktop_services_test.dart` — `pubspec.yaml` действительно подключает
  path-источник через `dependency_overrides`.

**Ручной Windows-сценарий (выполнен реально, 2026-10-24).**

1. `tool/occupy_hotkey.ps1` занял `Ctrl+Alt+B`.
2. Запуск debug-сборки: при старте получено
   `PlatformException(hotkey_busy, RegisterHotKey failed: the shortcut is
   already in use, 1409, null)`.
   `SettingsController` залогировал неудачное применение сохранённой
   комбинации; приложение продолжило работу, окно и UI остались доступны.
3. Helper остановлен; повторный запуск приложения залогировал
   `DesktopServices: горячая клавиша Ctrl + Alt + B зарегистрирована`.
4. В собранной `hotkey_manager_windows_plugin.dll` найдена строка
   `hotkey_busy` — используется пропатченный плагин, а не upstream.

**Честное ограничение:** смена комбинации через настройки и показ SnackBar
`hotkeyBusyError` требуют ручного клика в GUI и в этом проходе не
автоматизированы. Логика отката покрыта unit-тестами; сам факт обнаружения
занятости подтверждён нативным логом. Сырые логи —
`build/manual_busy_stdout.txt` и `build/manual_free_stdout.txt` (`build/`
исключён из git).

## R02-010 — backoff и повтор только отметки

**Что сделано.**

- В `ReminderScheduler` добавлено состояние попытки `_ReminderAttempt`
  (`failures`, `nextAttemptAt`, `shown`) на каждую задачу.
- Задержки: **30 с → 1 мин → 5 мин → 15 мин**; после успеха/изменения
  `remind_at`/удаления задачи состояние сбрасывается.
- Warning о неудаче пишется только при первой неудаче серии — без сообщения
  каждые 30 секунд.
- Если `show()` вернул `true`, но `markReminderSent` завершился ошибкой,
  повторяется **только отметка**; toast повторно не показывается.
- Если `show()` вернул `false`/бросил исключение, применяется backoff, и
  `reminder_sent_at` не выставляется.

**Файлы:** `lib/features/reminders/application/reminder_scheduler.dart`.

**Тесты (`test/reminder_scheduler_test.dart`):**

- «backoff 30 с → 1 мин → 5 мин → 15 мин» — failing notifier + fake clock
  (`clock`/ручное продвижение времени в тесте);
- «после успешного toast повторяется только отметка» — `show=true`,
  `markReminderSent` падает, следующий тик вызывает только отметку;
- существующие тесты `false`/исключение notifier и защита от устаревшего
  `remind_at` продолжют проходить.

## R02-011 — валюты на дашборде

**Что сделано.**

- `FinanceDraft.defaultCurrency = 'RUB'` — единый источник валюты по
  умолчанию; `FinanceTransaction.currency` использует его же.
- Дашборд передаёт `currency: FinanceDraft.defaultCurrency` в
  `FinanceRepository.summary`, поэтому доход/расход/баланс считаются только
  по одной валюте.
- Валюта отображается в подписи каждой ячейки через новый ARB-ключ
  `financeAmountWithCurrency` (`{label} · {currency}`), RU/EN.
- Операции в других валютах не смешиваются с рублёвыми.

**Файлы:** `lib/features/finance/domain/finance_transaction.dart`,
`lib/features/dashboard/presentation/dashboard_screen.dart`,
`lib/l10n/app_ru.arb`, `lib/l10n/app_en.arb`, generated l10n.

**Тесты:**

- `test/data_repositories_test.dart` — `summary(currency:)` возвращает только
  операции указанной валюты;
- `test/dashboard_widget_test.dart` — на дашборде две валюты (RUB + USD),
  сводка показывает только RUB и подпись содержит валюту.

## R02-012 — `RefreshIndicator` ждёт загрузку

**Что сделано.** `_reload()` в `dashboard_screen.dart` возвращает
`Future<void>`; `RefreshIndicator.onRefresh` получает именно его, кнопки
повтора/обновления тоже `await`-ят загрузку. Индикатор не исчезает до
завершения запросов.

**Тесты:** `test/dashboard_widget_test.dart` — «RefreshIndicator ждёт
завершения загрузки»: загрузка удерживается completer'ом, индикатор остаётся
на экране, затем исчезает.

## R02-013 — устаревший стартовый лог

**Что сделано.** В `lib/main.dart` сообщение «этап 0 — каркас» заменено на
актуальное `Second Brain: приложение запущено`. Отдельного regression-теста нет
(текстовая правка NIT).

## Обязательные проверки

Локально (Flutter 3.47.7, Dart 3.13.5):

| Команда | Результат |
|---------|-----------|
| `flutter pub get --enforce-lockfile` | OK |
| `flutter analyze --fatal-infos` | 0 issues |
| `flutter test` | **77/77** |
| `flutter build windows --debug` | success |
| `flutter gen-l10n` | без дрейфа; RU/EN по 128 message-ключей (+ `@@locale`) |

CI (проверено через `gh`):

- `92a9642` (включает `a50d972`) — run
  [40095276919](https://github.com/HoudiwinG/second-brain/actions/runs/40095276919),
  `analyze-and-test` и `build-windows` — **success**.
  Отдельный прогон для промежуточного `a50d972` не сохранился: следующий push
  отменил его через `concurrency`, поэтому доказательством служит прогон
  итогового коммита.

## Что осталось ручным для ревью №3

- Прокликать смену комбинации в настройках при занятом `Ctrl+Alt+B` и увидеть
  SnackBar `hotkeyBusyError` + откат на прежнюю комбинацию.
- Проверить меню/иконку трея и сам toast (как и в ревью №2, GUI-часть
  не автоматизирована).
- Оценить, достаточно ли вендорного патча и ручного лога для закрытия
  R02-009; альтернативой остаётся FFI-проба `RegisterHotKey` до регистрации.

## Риски и замечания

- Вендорный патч закреплён на upstream `0.2.0`; при обновлении
  `hotkey_manager` нужно перепроверить патч и `dependency_overrides`
  (зафиксировано в ADR-017).
- `analysis_options.yaml` исключает `third_party/**`; это осознанно, но
  означает, что ошибки в вендорном коде ловятся только нативной сборкой.
- Ручной сценарий подтверждает обнаружение занятости на старте; UI-откат
  проверен unit-тестами, не GUI-кликом.
