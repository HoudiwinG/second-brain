# Review: Stage-02

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
