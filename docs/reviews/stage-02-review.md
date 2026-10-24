# Review: Stage-02

> **Актуальный вердикт — в конце файла:** «Повторное ревью №3 (2026-10-24)» —
> **PASS WITH COMMENTS** (critical 0, major 0, minor 1, nit 1); R02-009 закрыт,
> stage-03 не блокируется. Разделы ниже — исторические ревью (состояние
> `296970b` и повторное №2).

- Дата (UTC): 2026-10-23 08:40
- Ревьюер: agent-2 (DeepSeek V4.1 Flash Free, OpenCode)
- Проверяемая ветка/коммит: `master` @ `296970b` (stage-02 — `82b04a2`;
  `origin/master` = `296970b`)
- Отчёт разработчика: [docs/stages/stage-02.md](../stages/stage-02.md)
- Метод: чтение `INDEX.md`, `context.md`, `decisions.md`, `tech-debt.md`,
  `stage-02.md`, ТЗ `PROMPT.md`/`STAGE_ONE.md`; сверка отчёта с кодом и тестами;
  проверка платформенной реализации `tray_manager 0.5.0` и поведения миграций
  в `drift 2.35.2`; локальные `flutter analyze`, `flutter test`,
  `flutter build windows --debug`; `git log/status/diff`.
- Ограничение среды: CI-run `39919792561` независимо не проверен — репозиторий
  приватный, `gh` в среде отсутствует. Локальные проверки выполнены как
  компенсация, но они не заменяют CI. Ручной Windows GUI-smoke независимо не
  воспроизводился; выводы о трее и toast сделаны по коду и отчёту разработчика.
- Локальные проверки: `flutter analyze --fatal-infos` — `No issues found!`;
  `flutter test` — `+57: All tests passed!`;
  `flutter build windows --debug` — success,
  `build\windows\x64\runner\Debug\second_brain.exe`.
- Рабочее дерево на момент проверки: только
  `windows/flutter/generated_plugin_registrant.h`, изменённый локальной сборкой
  (содержательных изменений нет); после проверки файл восстановлен.

## Итог

- Вердикт: **FAIL**
- Кол-во находок: critical: 0, major: 2, minor: 6, nit: 0
- Блокеры для перехода к следующему этапу:
  - **R02-001** — close-to-tray может оставить приложение без доступного трея
    при обычном запуске `.exe`.
  - **R02-002** — при ошибке показа toast напоминание помечается отправленным
    и теряется навсегда.

## Находки

### [MAJOR] R02-001: Иконка трея загружается относительным путём; close-to-tray может скрыть окно без трея

- **Категория:** A, G
- **Где:** `lib/app/desktop_services.dart:145-148`, `:162-168`, `:196-203`;
  Windows-реализация `tray_manager 0.5.0`
  (`windows/tray_manager_plugin.cpp:237-244`).
- **Что не так:** в `trayManager.setIcon` передаётся относительный путь
  `assets/tray_icon.ico`. `tray_manager` на Windows вызывает
  `LoadImage(..., LR_LOADFROMFILE)`, который разрешает путь относительно
  текущего рабочего каталога процесса, а не каталога `.exe` и не
  `data/flutter_assets`. В собранном приложении файл лежит только в
  `data\flutter_assets\assets\tray_icon.ico`; рядом с `.exe` каталога `assets`
  нет. При запуске из проводника/ярлыка (рабочий каталог — каталог `.exe` или
  другой) `LoadImage` возвращает `NULL`. При этом `tray_manager` не проверяет
  результат: `_ApplyIcon()` вызывает `Shell_NotifyIcon` с `hIcon == NULL`, а
  `SetIcon` всё равно отвечает `Success(true)`. В результате
  `DesktopServices._trayReady` становится `true`, `setPreventClose(true)`
  включается, и крестик скрывает окно, хотя доступного значка/меню трея нет.
  Пользователь может потерять окно; вернуть его можно только глобальным
  хоткеем (если он зарегистрирован).
- **Как воспроизвести:**
  1. `flutter build windows --debug`.
  2. Запустить `.exe` с рабочим каталогом самого `.exe`, как это делает
     Explorer/ярлык:
     ```powershell
     $exe = "$PWD\build\windows\x64\runner\Debug\second_brain.exe"
     Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
     ```
  3. Закрыть окно крестиком или `Alt+F4`.
  4. Проверить область уведомлений: иконки/меню приложения нет; процесс
     остаётся жив, окно скрыто.
  В отчёте `stage-02.md:214-230` приложение запускалось из корня репозитория,
  поэтому относительный путь случайно разрешался в существующий
  `assets/tray_icon.ico`. Это маскирует дефект.
- **Ожидаемое по ТЗ:** `docs/stages/stage-02.md:25` — «окно закрывается в трей,
  полный выход доступен из меню трея»; `:263-269` — ручной чек-лист требует
  вернуть окно кликом по иконке и выйти через меню трея. ADR-010/ADR-016.
- **Фактическое:** при штатном запуске из каталога `.exe` иконка не
  загружается; меню трея недоступно; окно скрывается, потому что
  `_trayReady` выставлен по «успешному» ответу плагина.
- **Предлагаемое исправление:** передавать абсолютный путь к bundled-ассету,
  вычисленный от `Platform.resolvedExecutable`, и не считать трей готовым,
  пока иконка не подтверждена. Например:
  ```diff
  +import 'dart:io';
  ...
  -      final iconPath = defaultTargetPlatform == TargetPlatform.windows
  -          ? 'assets/tray_icon.ico'
  -          : 'assets/tray_icon.png';
  +      final iconPath = defaultTargetPlatform == TargetPlatform.windows
  +          ? '${File(Platform.resolvedExecutable).parent.path}'
  +              '${Platform.pathSeparator}data'
  +              '${Platform.pathSeparator}flutter_assets'
  +              '${Platform.pathSeparator}assets'
  +              '${Platform.pathSeparator}tray_icon.ico'
  +          : 'assets/tray_icon.png';
  +      if (defaultTargetPlatform == TargetPlatform.windows &&
  +          !File(iconPath).existsSync()) {
  +        throw Exception('tray icon not found: $iconPath');
  +      }
         await trayManager.setIcon(iconPath);
  ```
  `throw Exception` (а не `Error`) важен: существующий `on Exception catch`
  оставит `_trayReady == false`, и `_hideOrClose()` завершит процесс вместо
  скрытия окна. Дополнительно стоит проверить фактическую готовность трея
  (например, через доступность контекстного меню/`getBounds`) и добавить
  Windows-тест запуска с `WorkingDirectory = Debug`. Если иконка не
  загрузилась, крестик должен завершать приложение, а не прятать его.
- **Связанные ADR:** ADR-006, ADR-010, ADR-016
- **Статус:** open

### [MAJOR] R02-002: Ошибка показа напоминания означает «отправлено»; напоминание теряется

- **Категория:** A, E, G
- **Где:** `lib/features/reminders/application/reminder_notifier.dart:47-69`;
  `lib/features/reminders/application/reminder_scheduler.dart:70-88`.
- **Что не так:** `LocalReminderNotifier.show` ловит все ошибки
  (`on Object`) и возвращает `Future<void>` без признака успеха. Если
  `localNotifier.setup` не удался, `_initialized` остаётся `false`, и `show`
  просто делает `return` (строки 50-51). Если `notification.show()` выбросил
  исключение, оно логируется и поглощается (строки 65-69). После любого такого
  возврата `ReminderScheduler._notify` считает показ успешным и вызывает
  `repository.markReminderSent` (строки 81-88). Задача больше не попадает в
  `dueReminders`, и пользователь не получает напоминание даже после
  восстановления WinToast/разрешений. Это не «работа без системных
  напоминаний», а потеря состояния напоминания.
- **Как воспроизвести:**
  1. Создать задачу с `remindAt` в прошлом.
  2. Смоделировать отказ WinToast: запретить создание ярлыка в Start Menu
     (`ShortcutPolicy.requireCreate`), либо в тесте подставить notifier,
     который возвращает управление без показа.
  3. Вызвать `ReminderScheduler.checkNow()`.
  4. Проверить БД: `reminderSentAt` заполнен, toast не показан; повторный
     `dueReminders` задачу не возвращает.
  Дефект виден и статически: в `show` нет ни `throw`, ни `bool`, поэтому
  вызывающая сторона не может отличить показ от ошибки.
- **Ожидаемое по ТЗ:** `docs/stages/stage-02.md:28-29` — наступившее
  напоминание показывается системным toast «не чаще одного раза»; ADR-015
  (идемпотентность через `reminder_sent_at`). Ошибка показа не должна
  трактоваться как доставка.
- **Фактическое:** любая ошибка notifier приводит к `markReminderSent`;
  напоминание исчезает навсегда.
- **Предлагаемое исправление:** сделать результат показа явным и помечать
  отправленным только при успехе:
  ```diff
  -abstract interface class ReminderNotifier {
  -  Future<void> show(ReminderMessage message);
  +abstract interface class ReminderNotifier {
  +  Future<bool> show(ReminderMessage message);
  }
  ...
  -    if (!_initialized) return;
  +    if (!_initialized) return false;
  ...
        await notification.show();
        AppLogger.d('ReminderNotifier: показано напоминание task-${message.taskId}');
  +     return true;
      } on Object catch (e, s) {
        AppLogger.e('ReminderNotifier: не удалось показать уведомление', e, s);
  +     return false;
      }
  ```
  В `_notify`:
  ```diff
  -      await _notifier.show(...);
  +      final shown = await _notifier.show(...);
  +      if (!shown) {
  +        AppLogger.w(
  +          'ReminderScheduler: напоминание task-${task.id} не показано, повторю позже',
  +        );
  +        return;
  +      }
        final marked = await repository.markReminderSent(...);
  ```
  `NoopReminderNotifier.show` должен возвращать `true` (намеренный no-op) или
  `false` с явной политикой; scheduler запускается только на Windows, поэтому
  практичнее `true`. Добавить тест с failing-notifier: `reminderSentAt`
  остаётся `NULL`, следующий тик повторяет попытку. Для повторных ошибок
  желательно ограничить частоту/добавить backoff, чтобы не спамить лог каждые
  30 секунд.
- **Связанные ADR:** ADR-015, ADR-016
- **Статус:** open

### [MINOR] R02-003: Результат применения сохранённого хоткея при старте игнорируется

- **Категория:** A, E
- **Где:** `lib/features/settings/application/settings_controller.dart:82-84`;
  `:180-194`; `lib/app/desktop_services.dart:70-110`.
- **Что не так:** `SettingsController.build` вызывает
  `unawaited(ref.read(quickHotkeyApplierProvider)(hotkey))` и игнорирует
  `false`. Если сохранённая комбинация B занята другим приложением,
  `DesktopServices.setQuickCaptureHotkey` восстанавливает предыдущую
  (default A), а `SettingsState.quickHotkey` всё равно содержит B. Настройки
  показывают B, хотя фактически зарегистрирована A; пользователь не получает
  сообщения об откате. Дополнительно `setQuickHotkey` при
  `current.quickHotkey == hotkey` сразу возвращает `true` (строка 183), поэтому
  выбрать ту же B повторно после неудачного старта нельзя — фактическая
  регистрация не перепроверяется. Это делает невозможным ручной retry без
  смены комбинации на другую и обратно.
- **Как воспроизвести:**
  1. Запустить второе приложение/утилиту, занимающую B (например,
     `Ctrl+Alt+B`).
  2. Сохранить B в настройках первого экземпляра, закрыть его.
  3. Запустить снова при занятой B.
  4. Открыть настройки: отображается B; нажатие B ничего не делает, A
     (default) работает.
- **Ожидаемое по ТЗ:** `docs/stages/stage-02.md:26-27` — комбинация
  сохраняется между запусками и корректно откатывается, если занята.
  ADR-016.
- **Фактическое:** регистрация откатывается в `DesktopServices`, но состояние
  настроек и UI остаются на сохранённой B; откат не виден и не сохраняется.
- **Предлагаемое исправление:** дождаться результата применения в `build`,
  при `false` применить и сохранить fallback (default), а также показать
  пользователю, что сохранённая комбинация недоступна. Например:
  ```diff
  -    unawaited(ref.read(quickHotkeyApplierProvider)(hotkey));
  +    final applied = await ref.read(quickHotkeyApplierProvider)(hotkey);
  +    final effective = applied ? hotkey : QuickHotkey.defaultBinding;
  +    if (!applied) {
  +      AppLogger.w(
  +        'SettingsController: ${hotkey.label} занята, использую default',
  +      );
  +      await ref.read(quickHotkeyApplierProvider)(effective);
  +    }
  ...
  -      quickHotkey: hotkey,
  +      quickHotkey: effective,
  ```
  Для повторного выбора той же комбинации убрать ранний `return true` или
  сверять состояние с фактически зарегистрированной комбинацией (например,
  через отдельный `currentHotkeyProvider`, чтобы не тянуть `DesktopServices`
  в контроллер настроек). Добавить тест startup-сценария с `apply == false`.
- **Связанные ADR:** ADR-016
- **Статус:** open

### [MINOR] R02-004: Проверка неподдерживаемой версии схемы стоит после DDL; возможна частичная миграция и тихий downgrade

- **Категория:** C
- **Где:** `lib/data/db/app_database.dart:261-287`;
  `test/db_migration_test.dart:94-129`.
- **Что не так:** `if (to > 3)` выполняется после веток миграции. Для
  `from = 2, to = 4` сначала выполняется `from < 3`: добавляется
  `tasks.reminder_sent_at` и создаются индексы, затем бросается
  `UnsupportedError`. `user_version` остаётся `2` (Drift пишет версию только
  после успешного `onUpgrade`), поэтому следующее открытие снова пытается
  добавить уже существующую колонку и падает на `duplicate column`.
  Для `from = 4, to = 3` ни одна ветка не срабатывает, а `to > 3` ложно;
  Drift считает открытие успешным и записывает `user_version = 3`. Это
  неподдерживаемый downgrade, который не отклоняется, хотя ADR-012 требует
  явного `UnsupportedError`. Текущий тест проверяет только `from = 3, to = 4`
  и не ловит ни частичную миграцию, ни downgrade.
- **Как воспроизвести:**
  1. Создать файл схемы v2.
  2. Открыть его тестовой БД с `schemaVersion = 4` и текущим `onUpgrade`.
  3. Получить `UnsupportedError`; проверить `PRAGMA user_version` (остался 2)
     и наличие `tasks.reminder_sent_at` (колонка уже создана).
  4. Повторно открыть — падение на `duplicate column`.
  5. Для downgrade: выставить в v3-файле `PRAGMA user_version = 4`, открыть
     обычной `AppDatabase` (v3); ошибки нет, версия становится 3.
- **Ожидаемое по ТЗ:** ADR-012 — неподдерживаемый переход должен явно падать,
  без `createAll` и без частичных изменений; `docs/stages/stage-02.md:164-166`.
- **Фактическое:** guard стоит слишком поздно; при `from > 3` его вообще нет.
- **Предлагаемое исправление:** проверять обе границы до любых DDL:
  ```diff
   onUpgrade: (Migrator m, int from, int to) async {
     AppLogger.d('AppDatabase: onUpgrade с $from до $to');
  +  if (from > 3 || to > 3) {
  +    throw UnsupportedError(
  +      'AppDatabase: нет миграции схемы $from → $to. '
  +      'Добавьте явную миграцию в onUpgrade (ADR-012).',
  +    );
  +  }
     if (from < 2) {
       ...
     } else if (from < 3) {
       ...
     }
  -  if (to > 3) {
  -    throw UnsupportedError(...);
  -  }
   },
  ```
  Добавить тесты: `v2 → v4` (проверить отсутствие изменений и `user_version`
  до/после), `v4 → v3` (ожидать `UnsupportedError` и сохранение версии 4).
- **Связанные ADR:** ADR-012
- **Статус:** open

### [MINOR] R02-005: Верхняя граница финансового месяца включена; операция 1-го числа 00:00 попадает в прошлый месяц

- **Категория:** A, E
- **Где:** `lib/features/dashboard/presentation/dashboard_screen.dart:37-51`;
  `lib/data/repositories/finance_repository.dart:199-204`.
- **Что не так:** дашборд передаёт `monthEnd = DateTime(now.year, now.month + 1)`
  (начало следующего месяца), а `FinanceRepository._query` использует
  `isSmallerOrEqualValue(to)`. Операция ровно в `monthEnd` (00:00 первого числа
  следующего месяца) включается в сводку прошлого месяца. В quick capture
  дата обычно ставится на 12:00, поэтому дефект редкий, но он воспроизводится
  для импортированных данных и для `DateTime.now()` в полночь; контракт
  «месяц» при этом неверный.
- **Как воспроизвести:** создать операцию с
  `date = DateTime(now.year, now.month + 1).toUtc()` и операцию в текущем
  месяце; вызвать `financeRepo.summary(from: monthStart, to: monthEnd)`;
  ожидается 1 операция, фактически 2.
- **Ожидаемое по ТЗ:** `docs/stages/stage-02.md:45` — доход/расход/баланс за
  текущий месяц; граница следующего месяца не должна входить.
- **Фактическое:** верхняя граница включительна, поэтому ровно граничная
  операция учитывается дважды (в текущем и следующем месяцах).
- **Предлагаемое исправление:** сделать `to` эксклюзивным и зафиксировать это
  в контракте:
  ```diff
   if (to != null) {
  -  query.where((t) => t.date.isSmallerOrEqualValue(to));
  +  query.where((t) => t.date.isSmallerThanValue(to));
   }
  ```
  Либо, не меняя семантику репозитория, в дашборде передавать
  `monthEnd.subtract(const Duration(microseconds: 1)).toUtc()`. Добавить тест
  на границу месяца.
- **Связанные ADR:** —
- **Статус:** open

### [MINOR] R02-006: Ошибка загрузки/сохранения в quick capture оставляет диалог в состоянии `_saving`

- **Категория:** E
- **Где:** `lib/features/quick_capture/presentation/quick_capture_dialog.dart:102-189`;
  `:20-28`.
- **Что не так:** `_save` выставляет `_saving = true`, после чего
  `ref.read(...future)` и `repo.create(...)` вызываются без `try/catch`.
  `Result` покрывает ошибки репозитория, но не ошибку получения провайдера
  (например, если БД не открылась) и не неожиданное исключение. В этом случае
  `_saving` остаётся `true`: кнопки «Сохранить»/«Отмена» disabled, локализованная
  ошибка не показывается; диалог можно закрыть только барьером. Если барьер
  закрыть во время записи, `mounted` уже `false`, и результат/ошибка теряются.
- **Как воспроизвести:** в тесте переопределить `notesRepositoryProvider`
  на `Future.error(...)` (или закрыть БД), открыть quick capture, ввести
  заголовок и нажать «Сохранить»; кнопки остаются disabled, `_error` пуст.
- **Ожидаемое по ТЗ:** чек-лист E — обработаны ошибки/офлайн; диалог должен
  показать локализованную ошибку и позволить повторить/отменить.
- **Фактическое:** необработанное исключение оставляет диалог в `_saving`.
- **Предлагаемое исправление:** обернуть загрузку/создание в
  `try/catch/finally` (или в отдельный метод, возвращающий `Result`):
  ```dart
  try {
    // текущий switch с repo.create
  } on Object catch (e, s) {
    AppLogger.e('QuickCaptureDialog: сохранение не удалось', e, s);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = lcm.errorUnexpected;
    });
  }
  ```
  На время `_saving` блокировать закрытие барьером (`PopScope`/`barrierDismissible:
  false` при сохранении) и добавить widget-тест с падающим репозиторием.
- **Связанные ADR:** —
- **Статус:** open

### [MINOR] R02-007: Тесты не покрывают failure-пути, из-за которых прошли R02-002/R02-003

- **Категория:** E
- **Где:** `test/reminder_scheduler_test.dart`, `test/settings_controller_test.dart`,
  `test/backup_service_test.dart`, `test/db_migration_test.dart`,
  `test/dashboard_widget_test.dart`.
- **Что не так:** тесты покрывают happy-path, но не заявленные контракты
  ошибок:
  - нет notifier, который не показывает уведомление/бросает исключение;
  - нет теста `SettingsController.build` с `apply == false` (проверяется
    только `setQuickHotkey`);
  - `backup_service_test.dart` не задаёт `reminderSentAt`, хотя экспорт/импорт
    поля реализованы (`backup_service.dart:238,461`);
  - нет теста границы финансового месяца (R02-005);
  - `db_migration_test.dart` проверяет только `v3 → v4`, но не `v2 → v4` и
    `v4 → v3` (R02-004).
- **Как воспроизвести:** запустить `flutter test` — все 57 проходят; затем
  добавить failing-notifier/startup-false тесты и увидеть отсутствие
  regression-защиты (тесты просто отсутствуют).
- **Ожидаемое по ТЗ:** чек-лист E — тесты покрывают бизнес-логику этапа;
  для каждого исправления ошибки — regression-тест.
- **Фактическое:** 57/57 зелёные, но критические failure-пути не покрыты.
- **Предлагаемое исправление:** добавить:
  1. `reminder_scheduler_test`: notifier возвращает `false`/бросает; проверить
     `reminderSentAt == null` и повторный вызов.
  2. `settings_controller_test`: startup apply `false`; проверить fallback.
  3. `backup_service_test`: задача с `reminderSentAt` проходит export/import.
  4. `dashboard_widget_test`/repository test: операция на границе месяца.
  5. `db_migration_test`: `v2 → v4` и `v4 → v3`.
- **Связанные ADR:** ADR-012, ADR-015, ADR-016
- **Статус:** open

### [MINOR] R02-008: Граница дня на дашборде считается как 24 часа, а не как следующая локальная полночь (DST)

- **Категория:** A, E
- **Где:** `lib/features/dashboard/presentation/dashboard_screen.dart:35-36`,
  `:61-70`.
- **Что не так:** `dayEnd = dayStart.add(const Duration(days: 1))` добавляет
  ровно 24 часа. В зоне с переходом на летнее/зимнее время локальные сутки
  могут длиться 23 или 25 часов. На весеннем переходе `dayEnd` окажется
  01:00 следующего дня, и задача в 00:30 будет ошибочно отнесена к сегодняшнему
  дню; на осеннем — 23:00, и задачи 23:00–00:00 выпадут из «сегодня».
  В России DST сейчас нет, но приложение поддерживает EN и не ограничено
  одной зоной.
- **Как воспроизвести:** в тестовой среде с `TZ=Europe/Berlin` взять дату
  весеннего перехода и задачу с `dueAt` в 00:30 следующего дня; дашборд
  покажет её в «Задачи на сегодня» за предыдущий день. В обычном `flutter
  test` локальная зона хоста может не иметь DST; проверка требует
  фиксированной TZ.
- **Ожидаемое по ТЗ:** `docs/stages/stage-02.md:21-22` — задачи на сегодня
  по локальному дню.
- **Фактическое:** граница дня зависит от абсолютных 24 часов, а не от
  локального календаря.
- **Предлагаемое исправление:**
  ```diff
  -    final dayEnd = dayStart.add(const Duration(days: 1));
  +    final dayEnd = DateTime(now.year, now.month, now.day + 1);
  ```
  `monthStart`/`monthEnd` уже используют конструктор `DateTime` и DST
  учитывают корректно. Добавить тест с фиксированной TZ, если тестовая
  инфраструктура это позволяет.
- **Связанные ADR:** —
- **Статус:** open

## Соответствие критериям приёмки

- [x] Дашборд: задачи на сегодня/просроченные, последние заметки/идеи,
  финансы за месяц, быстрые действия. Замечание: граница месяца — R02-005;
  DST-граница дня — R02-008.
- [ ] Быстрый ввод из трёх источников: дашборд и хоткей реализованы, но
  источник «меню трея» зависит от R02-001; обработка ошибок сохранения —
  R02-006.
- [ ] Окно закрывается в трей, полный выход доступен из меню трея: R02-001.
- [ ] Хоткей меняется, сохраняется и корректно откатывается: runtime-сценарий
  работает, startup-сценарий с занятой комбинацией — R02-003.
- [ ] Напоминание показывается не чаще одного раза: happy-path и
  `reminder_sent_at` работают, failure-path теряет напоминание — R02-002.
- [x] `flutter analyze --fatal-infos`, `flutter test`, `flutter build windows
  --debug` проходят локально: 0 issues, 57/57, build success. CI-run
  независимо не проверен (private repo, `gh` отсутствует).

## Расхождения документации с кодом

- `docs/stages/stage-02.md:214-230`: ручной smoke запускался из корня
  репозитория, а не из каталога `.exe`; контекстное меню и иконка трея вручную
  не проверялись. Это не позволяет закрыть критерий close-to-tray/меню трея и
  маскирует R02-001. `context.md:4-7` и `INDEX.md:4-7` формулируют smoke как
  пройденный, не уточняя это ограничение.
- `docs/stages/stage-02.md:164-166`: утверждение «непокрытый переход `to > 3`
  падает» неполно: `from = 2, to = 4` падает уже после частичного DDL, а
  `from = 4, to = 3` не падает вовсе (R02-004).
- `docs/context.md:12-13`: «Открытых MAJOR: 0» — после ревью открыто 2 MAJOR
  (R02-001, R02-002); строка обновлена вместе с этим журналом.
- `docs/context.md:100-101` и `docs/INDEX.md:43-44`: «ревью stage-02 не
  проводилось» — теперь проведено, вердикт FAIL; ссылки обновлены.
- `docs/tech-debt.md:22-28`: CI stage-02 заявлен success; независимо не
  проверен (private repo, нет `gh`). Локальные проверки воспроизведены, но
  attestation CI отсутствует.

## Рекомендации на следующий этап

1. **До stage-03** исправить R02-001 и R02-002 и добавить regression-тесты:
   запуск `.exe` с `WorkingDirectory = Debug` + проверка меню трея; failing
   notifier + проверка `reminderSentAt == null`.
2. Закрыть R02-003 и R02-004 до следующего изменения схемы/настроек: startup
   fallback хоткея должен быть видимым и сохраняемым; guard миграций — до DDL.
3. Закрыть R02-005/R02-006/R02-008 как часть полировки UX: эксклюзивная
   верхняя граница месяца, обработка ошибок quick capture, локальная граница
   дня.
4. Для Windows-smoke прикладывать артефакт (лог/скриншот) и запускать
   `.exe` из его каталога, а не из корня репозитория; отдельно проверять
   иконку, контекстное меню и выход.
5. Для CI в приватном репозитории добавить в отчёт attestation (`gh run view`
   или ссылку с логом), иначе reviewer не может независимо подтвердить
   success.
6. После исправлений обновить `stage-02.md`, `context.md`, `INDEX.md`,
   `tech-debt.md` и повторно прогнать `analyze/test/build`.

---

# Повторное ревью №2 (2026-10-24)

- **Дата (UTC):** 2026-10-24 12:10
- **Ревьюер:** agent-2 (DeepSeek V4.1 Flash Free, OpenCode)
- **Проверяемое состояние:** `master` @ `f9511c0`; код stage-02 —
  `82b04a2` (базовая реализация), `8956179` (исправления R02-001…R02-008);
  документация — `296970b`, `e8c6005`, `be2cd05`, `f9511c0`.
- **Отчёт разработчика:** [docs/stages/stage-02.md](../stages/stage-02.md)
- **Результаты исправлений:**
  [stage-02-review-results.md](stage-02-review-results.md) (self-check agent-1)
- **Метод:** чтение `INDEX.md`, `context.md`, `decisions.md` (ADR-015/016),
  `tech-debt.md`, `stage-02.md`, `PROMPT.md`/`STAGE_ONE.md`,
  `REVIEWER_PROMPT.md`; построчная сверка исправлений R02-001…R02-008 с кодом и
  тестами; чтение платформенных реализаций `tray_manager 0.5.0`,
  `hotkey_manager 0.2.3`/`hotkey_manager_windows 0.2.0` и `local_notifier 0.1.6`
  в pub-кэше; независимый прогон проверок и Windows-smoke.
- **Окружение (изменение с прошлого ревью):** на этом ПК установлен
  VS Build Tools 2022, `gh` авторизован под `HoudiwinG`, поэтому CI и GUI-smoke
  проверены независимо, а не по отчёту agent-1.

## Независимые проверки

| Проверка | Результат |
|----------|-----------|
| `flutter analyze --fatal-infos` | **0 issues** |
| `flutter test` | **69/69 passed** |
| `flutter build windows --debug` | **success**, `build\windows\x64\runner\Debug\second_brain.exe` |
| `flutter pub get --enforce-lockfile` | OK, lock согласован |
| `flutter gen-l10n` | без изменений в дереве; RU/EN — по 128 ключей |
| `git status --short` | чисто (после удаления временного smoke-теста) |
| CI `82b04a2` — [39919792561](https://github.com/HoudiwinG/second-brain/actions/runs/39919792561) | **success** |
| CI `296970b` — [39920666645](https://github.com/HoudiwinG/second-brain/actions/runs/39920666645) | **success** |
| CI `e8c6005` (включает код `8956179`) — [39931858624](https://github.com/HoudiwinG/second-brain/actions/runs/39931858624) | **success** |
| CI `f9511c0` — [40091767297](https://github.com/HoudiwinG/second-brain/actions/runs/40091767297) | **success** |

**Windows-smoke (2026-10-24, выполнен ревьюером, не по отчёту):**

1. `.exe` запущен с рабочим каталогом `build\windows\x64\runner\Debug`;
   окно «Second Brain» открылось, процесс стабилен.
2. В рабочую БД (`%APPDATA%\com.secondbrain\second_brain\second_brain.db`,
   schema v3) добавлена задача с `remind_at` на минуту в прошлом.
3. После старта планировщик записал `reminder_sent_at = 1792843515` — значит
   `LocalReminderNotifier.show` вернул `true`, WinToast инициализировался, а
   `markReminderSent` выполнился.
4. Через 40 с (следующий тик) значение `reminder_sent_at` не изменилось —
   повторной отметки нет; задача больше не выбирается как наступившая.
5. `taskkill /PID <pid>` без `/F` (WM_CLOSE): процесс остался жив,
   `IsWindowVisible = false` — close-to-tray сработал. Это косвенно
   подтверждает и R02-001: окно скрывается, только если `_trayReady == true`,
   т.е. иконка и меню действительно установлены (при ошибке трея приложение
   завершилось бы).
6. `data\flutter_assets\assets\tray_icon.ico` существует рядом с `.exe`.

Ограничения smoke: иконка/меню трея визуально не проверялись (возможен overflow
области уведомлений), сам toast визуально не наблюдался, физическое нажатие
`Ctrl+Alt+B` не эмулировалось. Вывод о hotkey ниже опирается на исходники
плагина, а не на GUI-наблюдение.

## Итог

- **Вердикт: FAIL**
- **Кол-во находок:** critical: 0, major: 1, minor: 2, nit: 2
- **Блокеры для перехода к stage-03:**
  - **R02-009** — занятая глобальная комбинация не детектируется на Windows:
    критерий приёмки «корректно откатывается, если комбинация занята» не
    выполняется, а UI молча показывает неработающую комбинацию.
- **Важно:** R02-001…R02-008 закрыты (проверено ниже). R02-009 — не регрессия
  исправлений, а ограничение зависимости, которое эти исправления
  замаскировали: production-ветка `false` недостижима.
- **Альтернатива для владельца продукта:** если ограничение официально
  принимается как техдолг (TD-27) и критерий этапа переформулируется
  («откат реализован, обнаружение занятости — TD»), вердикт может быть
  **PASS WITH COMMENTS**. Ревьюер не вправе принимать это решение
  самостоятельно; на момент проверки критерий не выполнен → **FAIL**.

## Проверка закрытия R02-001…R02-008

| ID | Статус | Доказательство |
|----|--------|----------------|
| R02-001 | fixed | `desktop_services.dart:45-60` — абсолютный путь от `Platform.resolvedExecutable` + `File.existsSync()` (`:171-191`); `_trayReady` выставляется после `setIcon`/`setToolTip`/`setContextMenu`. Smoke: WM_CLOSE оставил процесс живым при скрытом окне. Тесты пути — `test/desktop_services_test.dart`. |
| R02-002 | fixed | `ReminderNotifier.show → Future<bool>` (`reminder_notifier.dart:16,52-77`); `markReminderSent` только при `true` (`reminder_scheduler.dart:81-96`). Тесты false/throw — `test/reminder_scheduler_test.dart`. Smoke: `reminder_sent_at` записан после успешного показа. |
| R02-003 | fixed (логика) | Startup: `await apply`, fallback на default с сохранением, состояние отражает применённое (`settings_controller.dart:86-105`); при ошибке сохранения — откат (`:221-280`). Тест startup=false. **Но** реальный Windows-applier всегда возвращает `true` — см. R02-009. |
| R02-004 | fixed | Guard `from > to || from > 3 || to > 3` до DDL (`app_database.dart:267`); тесты `v2 → v4` (нет частичной миграции, `user_version = 2`) и `v4 → v3` (UnsupportedError, версия не перезаписана) — `test/db_migration_test.dart:94-221`. |
| R02-005 | fixed | `[from, to)` через `isSmallerThanValue` (`finance_repository.dart:199-207`); тест границы месяца — `test/data_repositories_test.dart:274-299`. |
| R02-006 | fixed | `try/catch/finally`, локализованная ошибка, сброс `_saving` (`quick_capture_dialog.dart:114-211`); widget-тест падающего репозитория. |
| R02-007 | fixed | Добавлены regression-тесты: failing notifier, startup-apply false, backup `reminderSentAt`, границы месяца, миграции, quick capture, путь трея. Итог — 69 тестов. |
| R02-008 | fixed | Календарные границы `DateTime(y, m, d + 1)` / `DateTime(y, m + 1)` (`dashboard_period.dart`); тест семантики. |

## Новые находки

### [MAJOR] R02-009: занятая глобальная комбинация не обнаруживается на Windows

- **Категория:** A (не выполнен критерий этапа), E (тесты дают ложную
  уверенность), G (платформенное ограничение зависимости)
- **Где:** `lib/app/desktop_services.dart:96-131`;
  `lib/features/settings/application/settings_controller.dart:86-105,221-280`;
  `lib/features/settings/presentation/settings_screen.dart:197-214`;
  `test/settings_controller_test.dart:122-200`;
  `hotkey_manager 0.2.3` →
  `hotkey_manager_windows-0.2.0/windows/hotkey_manager_windows_plugin.cpp:104-108`.
- **Что не так:** нативный плагин вызывает `RegisterHotKey(...)` и **игнорирует
  возвращённый `BOOL`**, после чего всегда отвечает
  `result->Success(EncodableValue(true))`. Dart-обёртка
  `HotKeyManager.register` возвращает `Future<void>`. Поэтому
  `DesktopServices.setQuickCaptureHotkey` на Windows **не может вернуть
  `false`**: ветки отката на прежнюю комбинацию и SnackBar
  `hotkeyBusyError` в production недостижимы. Если комбинацию уже занимает
  другое приложение, приложение молча показывает её как активную, но хоткей не
  работает. Тесты подменяют applier через
  `quickHotkeyApplierProvider.overrideWithValue((_) async => false)` и
  проверяют недостижимую в реальности ветку.
- **Как воспроизвести:**
  1. Зарезервировать `Ctrl+Alt+B` через `RegisterHotKey` в любом другом
     процессе (или выбрать в настройках заведомо занятую комбинацию).
  2. Запустить `second_brain.exe`, задать эту комбинацию в настройках.
  3. Ожидаемого сообщения об ошибке/отката нет; нажатие комбинации не открывает
     быстрый ввод, в настройках отображается «активная» комбинация.
  4. Источник: строки 104-108 плагина — результат `RegisterHotKey` не
     проверяется.
- **Ожидаемое по ТЗ:** `docs/stages/stage-02.md`, раздел «Критерии приёмки
  stage-02», пункт про горячую комбинацию — «меняется в настройках,
  сохраняется между запусками и корректно откатывается, если комбинация
  занята». То же обещает ADR-016 («безопасный откат при занятой комбинации»,
  «при ошибке регистрации/сохранения откатывает состояние и прежнюю
  комбинацию»).
- **Фактическое:** смена и сохранение работают; откат при занятой комбинации не
  работает и не может сработать с текущей зависимостью; UI вводит в
  заблуждение.
- **Предлагаемое исправление (не применять без указания):**
  1. Предпочтительно — форк/патч `hotkey_manager_windows` (или переход на
     поддерживаемый пакет), возвращающий результат `RegisterHotKey`:
     `if (!::RegisterHotKey(...)) { result->Error("hotkey_busy", ...); return; }`.
     Тогда существующий `try/catch` в `setQuickCaptureHotkey` корректно вернёт
     `false` и сработает откат. Обновление зависимости не поможет: `0.2.3` —
     последняя версия `hotkey_manager` на pub.dev (проверено 2026-10-24),
     платформенный плагин в ней тот же.
  2. Альтернатива — FFI-проба `RegisterHotKey`/`UnregisterHotKey` в
     `DesktopServices` до регистрации через плагин (нужен HWND/поток и
     аккуратность, чтобы не конфликтовать с самим плагином).
  3. Если исправление откладывается — оформить TD-27, убрать из отчёта
     утверждение о работающем откате, добавить в ручной чек-лист сценарий
     «занятая комбинация»; вердикт этапа в этом случае — PASS WITH COMMENTS.
- **Связанные ADR:** ADR-016, TD-15; уточнение к TD-03 (см. расхождения).
- **Статус:** open

### [MINOR] R02-010: повторные неудачи toast не имеют backoff и ограничения

- **Категория:** E (надёжность/логирование)
- **Где:** `lib/features/reminders/application/reminder_scheduler.dart:70-105`,
  `lib/features/reminders/application/reminder_notifier.dart:52-77`.
- **Что не так:** если Windows не может показать уведомление (WinToast не
  инициализировался, уведомления отключены политикой), `show()` возвращает
  `false`, задача не помечается, и каждые 30 секунд повторяются попытка и
  предупреждение в лог — бесконечно. Симметрично: если toast показан, а
  `markReminderSent` не удался, на следующем тике пользователь получит
  повторный toast (до успешной записи). Оригинальное ревью рекомендовало
  backoff, но он не реализован.
- **Воспроизвести:** отключить уведомления приложения в Windows → задача с
  наступившим `remind_at` → в логе предупреждение каждые 30 с.
- **Ожидаемое:** деградация без спама; напоминание не теряется.
- **Фактическое:** неограниченные повторы каждые 30 с.
- **Предлагаемое исправление:** in-memory карта попыток
  (`taskId → attemptCount/nextAttemptAt`) с экспоненциальной задержкой
  30 с → 1 мин → 5 мин → 15 мин; логировать первый сбой и смену интервала.
  Тест: failing notifier + fake clock, проверить интервалы.
- **Связанные ADR:** ADR-015.
- **Статус:** open

### [MINOR] R02-011: финансовая сводка дашборда суммирует разные валюты

- **Категория:** A (данные на экране этапа)
- **Где:** `lib/features/dashboard/presentation/dashboard_screen.dart:44-56`,
  `lib/data/repositories/finance_repository.dart:156-185`,
  `lib/features/finance/domain/finance_transaction.dart:72`
  («смешивание валют не поддерживается»),
  `lib/features/finance/presentation/finance_screen.dart:402` (валюта
  редактируется, по умолчанию `RUB`).
- **Что не так:** дашборд вызывает `summary(from: month.start, to: month.end)`
  без `currency`, а репозиторий складывает суммы всех валют. При наличии
  операций в USD/EUR «доход за месяц» будет суммой рублей и долларов, а
  подпись валюты на карточке отсутствует. Домен прямо говорит, что смешивание
  не поддерживается.
- **Воспроизвести:** создать доход 100 RUB и 100 USD в текущем месяце →
  дашборд покажет 200.00.
- **Ожидаемое:** сводка в одной валюте (по умолчанию/настройке) либо разбивка
  по валютам.
- **Фактическое:** числа разных валют складываются.
- **Предлагаемое исправление:** передавать валюту по умолчанию
  (`FinanceDraft.defaultCurrency` / настройка) в `summary(currency: ...)` либо
  показывать по карточке на валюту; добавить тест с двумя валютами.
- **Связанные ADR:** — (TD-21 про `REAL`, не про валюты).
- **Статус:** open

### [NIT] R02-012: `RefreshIndicator` завершается до окончания загрузки

- **Категория:** E (UX)
- **Где:** `lib/features/dashboard/presentation/dashboard_screen.dart:135`.
- **Что не так:** `onRefresh: () async => _reload()` не ждёт загрузку:
  `_reload` только подменяет `_future`, поэтому индикатор исчезает сразу,
  хотя данные ещё грузятся. При ошибке индикатор тоже считается успешным.
- **Предлагаемое исправление:** сделать `_reload` возвращающим `Future` и
  `await` его в `onRefresh` (с обработкой ошибок через `FutureBuilder`).
- **Статус:** open

### [NIT] R02-013: устаревший текст лога «этап 0 — каркас»

- **Категория:** F (документация/тексты)
- **Где:** `lib/main.dart:11,30`.
- **Что не так:** комментарий и стартовый лог по-прежнему называют приложение
  «этап 0 — каркас», хотя реализован stage-02.
- **Предлагаемое исправление:** заменить на нейтральное «Second Brain:
  приложение запущено» (или версию этапа), чтобы лог не вводил в заблуждение
  при разборе инцидентов.
- **Статус:** open

## Соответствие критериям приёмки

- [x] Дашборд: задачи на сегодня/просроченные, последние заметки/идеи, финансы
  за месяц, быстрые действия — код + widget-тесты; в smoke дашборд отрисован.
- [x] Быстрый ввод из дашборда, меню трея и по глобальной комбинации — диалог,
  host и три источника реализованы; из трея/хоткея вручную не проверялось,
  но путь единый и покрыт кодом.
- [x] Окно закрывается в трей, полный выход из меню — close-to-tray подтверждён
  независимым smoke; quit проверен по коду (вручную не нажимался).
- [ ] Горячая комбинация меняется, сохраняется и откатывается при занятости —
  смена/сохранение есть, откат при занятой комбинации недостижим (R02-009).
- [x] Напоминание показывается не чаще одного раза — smoke: `reminder_sent_at`
  записан и стабилен на следующем тике; тесты failure-path. Оговорка: при сбое
  записи отметки возможен повтор toast (R02-010).
- [x] `flutter analyze --fatal-infos` (0), `flutter test` (69/69),
  `flutter build windows --debug` (success) — локально и в CI.

## Расхождения документации с кодом

1. `docs/stages/stage-02.md` (критерии п. 4, раздел «Настраиваемая горячая
   клавиша»), `docs/context.md` (раздел «Быстрый ввод, трей, хоткей»),
   `docs/tech-debt.md` (TD-15), `docs/decisions.md` (ADR-016, «Решение» и
   «Последствия»): заявлен работающий откат при занятой комбинации; фактически
   ветка недостижима на Windows (R02-009). По правилу 6 это MAJOR сам по себе;
   после исправления кода или официального принятия TD формулировки ADR/отчёта
   нужно привести к факту.
2. `docs/tech-debt.md` (TD-03): «занятая комбинация (другое приложение)
   выбрасывала исключение из `main()`» — для `hotkey_manager 0.2.3` неверно:
   плагин игнорирует результат и не бросает исключение. Исключение возможно
   только при других сбоях platform channel. Требуется уточнение, иначе
   следующий агент снова будет искать несуществующий throw (уточнение внесено
   в TD-27).
3. `docs/stages/stage-02.md` (шапка отчёта): «CI для `8956179` не проверен
   независимо» — теперь проверен: run `39931858624` для `e8c6005` (код
   `8956179` в истории) — success; run `40091767297` для `f9511c0` — success.
4. `docs/INDEX.md`, `docs/context.md`, `docs/tech-debt.md` (раздел о проверке):
   «CI независимо не проверен (private repo)» — `gh` авторизован, все четыре
   run проверены (`gh run list`).
5. `docs/stages/stage-02.md` (раздел «Известные ограничения») и
   `docs/INDEX.md` (раздел «Ревью»): «повторное ревью не проводилось» —
   проведено, вердикт **FAIL** (R02-009).
6. `docs/context.md` (блок «Статус»): «Открытых MAJOR: 0» — теперь 1 (R02-009).
7. `docs/stages/stage-02.md` (раздел «Как запустить и проверить этап»): в ручном
   чек-листе не было сценария «занятая комбинация»; добавлен, иначе R02-009 не
   будет пойман вручную.
8. `lib/main.dart:11,30` — устаревший «этап 0 — каркас» (R02-013).

## Рекомендации на следующий этап

1. **До stage-03 закрыть R02-009** (блокер): патч/форк платформенного
   плагина с возвратом результата `RegisterHotKey` либо FFI-проба. После
   исправления добавить в ручной чек-лист Windows сценарий «комбинация занята
   другим приложением» и приложить лог/скриншот; CI GUI-хоткей не покрывает.
   Если решено принять ограничение — оформить TD-27, переписать критерий
   этапа и запросить PASS WITH COMMENTS. Готовые задачи и эскизы патчей:
   [stage-02-fix-tasks.md](stage-02-fix-tasks.md).
2. R02-010: backoff и ограничение повторов, один warning вместо спама; тест
   с failing notifier и fake clock.
3. R02-011: фильтр валюты в сводке дашборда или разбивка по валютам; тест с
   двумя валютами.
4. R02-012/R02-013 — быстрые правки вместе с ближайшим коммитом.
5. После правок: `flutter analyze --fatal-infos`, `flutter test`,
   `flutter build windows --debug`, обновить `stage-02.md`, `context.md`,
   `INDEX.md`, `tech-debt.md`, `docs/debug/log.md`; запросить ревью №3,
   сфокусированное на R02-009.
6. Stage-03 (LLM-слой) **не начинать** до вердикта без открытых MAJOR.

## Что подтверждено положительно

- Все восемь находок первого ревью закрыты в коде и покрыты тестами; smoke
  R02-001/R02-002 воспроизведён независимо на этой машине.
- Миграционный guard действительно стоит до DDL и проверен на `v2 → v4` и
  `v4 → v3` (включая сохранность `user_version`).
- Локализация: 128 ключей в RU/EN, `gen-l10n` без дрейфа, хардкод-строк в UI не
  найдено, тексты трея/окна берутся из ARB.
- Секретов в индексе нет (`.env` исключён, только `.env.example`); содержимое
  заметок/задач в логи не пишется; `is_private_for_llm` не затрагивается
  быстрым вводом.
- `pubspec.lock` согласован (`--enforce-lockfile` OK); CI зелёный на всех
  проверенных коммитах; дерево чистое.

---

## Повторное ревью №3 (2026-10-24)

- **Дата (UTC):** 2026-10-24 13:15
- **Ревьюер:** agent-2 (DeepSeek V4.1 Flash Free, OpenCode)
- **Проверяемый коммит:** `master` @ `07fa5b9` (`a50d972` — R02-009/010,
  `92a9642` — R02-011…013, `07fa5b9` — документация); `origin/master` совпадает.
- **Метод:** чтение diff `2c591a8..07fa5b9`, кода и тестов, ADR-017, TD-27,
  `stage-02.md`, `stage-02-fix-results.md`; независимые `flutter pub get
  --enforce-lockfile`, `analyze --fatal-infos`, `test`, `build windows --debug`,
  `gen-l10n`; проверка состава DLL и `.flutter-plugins-dependencies`; `gh run
  view`; независимый запуск busy/free-сценария через
  `tool/occupy_hotkey.ps1`; `git status/diff --check`.
- **Ограничение среды:** GUI-клик «занять комбинацию и выбрать её в настройках»
  с визуальной проверкой SnackBar не автоматизирован. Startup-сценарий занятой
  комбинации и возврат свободной комбинации воспроизведены на этой машине.

### Итог

- **Вердикт: PASS WITH COMMENTS**
- Находки: critical **0**, major **0**, minor **1** (R02-014), nit **1**
  (R02-015).
- R02-009…R02-013 закрыты. Блокеров stage-03 нет; оба комментария
  ниже не блокируют LLM-слой и могут быть закрыты отдельным коммитом.
- Ручной GUI-шаг для R02-009 остаётся обязательным перед релизной проверкой
  (см. чек-лист stage-02, п. 6).

### R02-009 — занятая глобальная комбинация: подтверждено

- В `third_party/hotkey_manager_windows/windows/hotkey_manager_windows_plugin.cpp`
  (строки 104-119) результат `::RegisterHotKey` проверяется; при `FALSE`
  возвращается `result->Error("hotkey_busy", …)` с `GetLastError()` и `return`
  **до** вставки в `hotkey_id_map_`. Патч минимален, `LICENSE` upstream сохранён.
- `pubspec.yaml` содержит `dependency_overrides: hotkey_manager_windows: path:
  third_party/hotkey_manager_windows`; `.flutter-plugins-dependencies` указывает
  на этот каталог, а в собранной
  `build/windows/x64/runner/Debug/hotkey_manager_windows_plugin.dll` найдена
  строка `hotkey_busy`. То есть проверялась именно пропатченная DLL, а не
  версия из pub-кэша.
- `DesktopServices.applyHotkeyBinding` действительно ловит `PlatformException`,
  снимает новую комбинацию, повторно регистрирует предыдущую и возвращает
  `false`; `SettingsController.setQuickHotkey` откатывает состояние и возвращает
  `false`, а экран настроек показывает локализованный `hotkeyBusyError`. Это
  подтверждено `test/desktop_services_test.dart` и
  `test/settings_controller_test.dart`; сам SnackBar в widget-тесте не
  проверялся.
- Независимый запуск: `tool/occupy_hotkey.ps1` занял `Ctrl+Alt+B`, приложение
  осталось живо и залогировало
  `PlatformException(hotkey_busy, RegisterHotKey failed: the shortcut is
  already in use, 1409, null)`; после остановки helper'а повторный запуск
  залогировал успешную регистрацию `Ctrl + Alt + B`. Сырые логи этого прогона —
  `build/review_busy_out.txt` и `build/review_free_out.txt` (`build/` вне git).
- **Что не проверено вручную:** смена комбинации через настройки с занятой
  комбинацией и появление SnackBar `hotkeyBusyError`. Код этой ветки не менялся
  в проходе и покрыт unit-тестом контроллера, но для полного соответствия
  критерию R02-009 нужен один ручной клик по чек-листу.

### R02-010 — backoff и повтор только отметки

- Реализованы задержки 30 с → 1 мин → 5 мин → 15 мин на задачу, состояние
  (`failures`, `nextAttemptAt`, `shown`) сбрасывается при успешной отметке и
  изменении `remind_at`; после успешного `show()` при сбое
  `markReminderSent` повторяется только отметка.
- Тест `test/reminder_scheduler_test.dart` проверяет интервалы на fake clock и
  отсутствие второго toast. Замечание по логу — R02-015 ниже.

### R02-011 — валюта на дашборде

- `FinanceDraft.defaultCurrency` — единый источник (`RUB`); `summary` получает
  `currency`, карточка подписана `financeAmountWithCurrency` («Доход · RUB»);
  тест с RUB/USD подтверждает, что USD не попадает в сумму. Замечание по
  экрану финансов — R02-014 ниже.

### R02-012/R02-013

- `_reload()` возвращает `Future<void>`, `RefreshIndicator.onRefresh` ждёт её;
  widget-тест с `Completer` подтверждает, что индикатор не завершается раньше
  загрузки.
- Лог в `main.dart` заменён на «Second Brain: приложение запущено»; в логах/UI
  «этап 0» больше не встречается. В двух doc-комментариях (`settings_screen.dart`,
  `placeholder_section_screen.dart`) слово «этап 0» осталось, но это не UI и не
  лог, поэтому R02-013 не переоткрывается.

### Новые комментарии (не блокируют stage-03)

#### [MINOR] R02-014: сводка на экране финансов по-прежнему смешивает валюты

- **Где:** `lib/features/finance/presentation/finance_screen.dart:26-30`
  (`repo.summary()` без `currency`), `:149-180` (`_SummaryCard` без подписи
  валюты).
- **Что не так:** R02-011 исправил дашборд, но на самом экране финансов
  «Доход/Расход/Баланс» по-прежнему суммируют все валюты. При 100 RUB + 100 USD
  карточка покажет 200.00 без указания валюты.
- **Ожидаемое:** та же валюта по умолчанию, что и на дашборде, либо разбивка
  по валютам; подпись валюты обязательна.
- **Предложение:** передать `currency: FinanceDraft.defaultCurrency` в
  `summary()` и использовать `financeAmountWithCurrency` (или сделать
  группировку по валютам); добавить widget/unit-тест с двумя валютами.
- **Статус:** open (comment, MINOR). Не блокирует stage-03.

#### [NIT] R02-015: сбой отметки напоминания логируется на каждом retry

- **Где:** `lib/features/reminders/application/reminder_scheduler.dart:163-169`.
- **Что не так:** при `markReminderSent → Failure` вызывается
  `AppLogger.appError(error)` на каждой попытке, включая повторы каждые 15
  минут. `_scheduleRetry` аккуратно ограничивает warning, но error-лог этого
  ограничения не имеет; обещание «лог без спама» из R02-010 выполняется не
  полностью.
- **Предложение:** логировать `appError` только при `attempt.failures == 0`
  (или при смене интервала), как в `_scheduleRetry`; при желании добавить тест
  на количество логов.
- **Статус:** open (comment, NIT). Не блокирует stage-03.

### Независимые проверки

| Проверка | Результат |
|----------|-----------|
| `flutter pub get --enforce-lockfile` | OK; `hotkey_manager_windows 0.2.0 from path third_party\...` |
| `flutter analyze --fatal-infos` | **No issues found!** |
| `flutter test` | **77/77**, All tests passed |
| `flutter build windows --debug` | **success**; `build\windows\x64\runner\Debug\second_brain.exe` |
| `flutter gen-l10n` | без дрейфа; 128 message keys в RU/EN (+ `@@locale`); `git status` чист |
| DLL | `hotkey_manager_windows_plugin.dll` содержит `hotkey_busy` |
| Busy-сценарий | `PlatformException(hotkey_busy, …, 1409)`; процесс жив |
| Free-сценарий | `горячая клавиша Ctrl + Alt + B зарегистрирована` |
| CI `40095276919` (`92a9642`) | success; `analyze-and-test` + `build-windows` |
| CI `40095857001` (`07fa5b9`) | success; `analyze-and-test` + `build-windows` |
| CI `40097546532` (`1fd60d3`, документация) | success; `analyze-and-test` + `build-windows` |
| `git status --short` | пусто до правок документации; `git diff --check` без ошибок |

### Документация

- ADR-017, TD-27, `stage-02.md`, `context.md`, `INDEX.md`,
  `stage-02-fix-results.md` соответствуют коду; TD-27 переведён в `fixed`.
- В отчёте разработчика и двух живых документах было указано «129 ключей»
  локализации. Фактически в ARB **128** message-ключей (плюс `@@locale`);
  в живых документах счёт исправлен на 128. На вердикт это не влияет.
- Секретов в индексе нет; `.env` исключён, в репозитории только
  `.env.example`; дерево чистое.

### Что подтверждено положительно

- R02-009 закрыт по коду, unit-тестам и независимому Windows-smoke; вендорный
  патч действительно попадает в сборку.
- R02-010/R02-011/R02-012/R02-013 закрыты, regression-тесты осмысленные
  (fake clock, две валюты, gated repository, controller failure).
- `analyze`/`test`/`build`/CI воспроизводятся; документация в основном точная
  и честно отмечает, что GUI-шаг не прокликан.

### Рекомендации

1. Перед релизной проверкой stage-02 вручную пройти п. 6 чек-листа: занять
   `Ctrl+Alt+B`, выбрать её в настройках, увидеть `hotkeyBusyError`, убедиться
   в откате; после освобождения — успешная регистрация.
2. R02-014 и R02-015 закрыть отдельным небольшим коммитом (или зафиксировать
   как TD), они не блокируют stage-03.
3. При обновлении `hotkey_manager` заново сверить вендорный патч с новой
   версией `hotkey_manager_windows` (ADR-017) и повторить busy-smoke.
