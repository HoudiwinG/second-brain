# Stage-02 — задачи по повторному ревью №2 и патч-предложения

- **Дата (UTC):** 2026-10-24
- **Автор:** agent-2 (ревьюер)
- **Источник:** [stage-02-review.md](stage-02-review.md), раздел
  «Повторное ревью №2»
- **Состояние:** `master` @ `840bb9e` (код stage-02 — `82b04a2` + `8956179`)
- **Вердикт ревью:** **FAIL**, открыт 1 MAJOR (R02-009)
- **Назначение:** готовые задачи для agent-1. Ревьюер код не правил; ниже —
  предложения, а не применённые изменения.

## Порядок работ

1. R02-009 — блокер stage-03 (MAJOR).
2. R02-010 и R02-011 — вместе с R02-009 одним PR/коммитом (MINOR).
3. R02-012 и R02-013 — попутно (NIT).
4. Обновить документацию, прогнать проверки, запросить ревью №3.

---

## R02-009 — обнаруживать занятую глобальную комбинацию (MAJOR, блокер)

**Проблема.** `hotkey_manager_windows 0.2.0` вызывает `RegisterHotKey` и
игнорирует результат, всегда отвечая успехом
(`hotkey_manager_windows_plugin.cpp:104-108`). `DesktopServices.
setQuickCaptureHotkey` не может вернуть `false`, поэтому откат и
`hotkeyBusyError` недостижимы. `hotkey_manager 0.2.3` — последняя версия на
pub.dev (2026-10-24), обновление не помогает.

**Критерии готовности:**

- [ ] Комбинация, занятая другим процессом, не регистрируется «молча».
- [ ] Пользователь видит локализованную ошибку `hotkeyBusyError`.
- [ ] Прежняя комбинация восстанавливается, состояние настроек откатывается.
- [ ] Свободная комбинация по-прежнему регистрируется и сохраняется между
      запусками.
- [ ] Ручной Windows-сценарий «занять комбинацию другим приложением» пройден,
      результат приложен к отчёту (лог/скриншот).
- [ ] `analyze` 0, `test` зелёные, `build windows --debug` success, CI зелёный.

### Вариант A (рекомендуемый): вендорный патч платформенного плагина

1. Скопировать `hotkey_manager_windows-0.2.0` из pub-кэша в
   `third_party/hotkey_manager_windows/` (или сделать форк и подключить
   git-зависимость).
2. В `windows/hotkey_manager_windows_plugin.cpp` заменить:

   ```cpp
   ::RegisterHotKey(
       ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT),
       hotkey_id, fs_modifiers, key_code);
   hotkey_id_map_.insert(std::make_pair(identifier, hotkey_id));
   result->Success(flutter::EncodableValue(true));
   ```

   на:

   ```cpp
   if (!::RegisterHotKey(
           ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT),
           hotkey_id, fs_modifiers, key_code)) {
     result->Error(
         "hotkey_busy",
         "RegisterHotKey failed",
         flutter::EncodableValue(static_cast<int64_t>(::GetLastError())));
     return;
   }
   hotkey_id_map_.insert(std::make_pair(identifier, hotkey_id));
   result->Success(flutter::EncodableValue(true));
   ```

3. Подключить патч в `pubspec.yaml`:

   ```yaml
   dependency_overrides:
     hotkey_manager_windows:
       path: third_party/hotkey_manager_windows
   ```

4. Dart-код менять не нужно: `setQuickCaptureHotkey` уже ловит `Exception`
   (`PlatformException` — его подтип), логирует и восстанавливает предыдущую
   комбинацию (`desktop_services.dart:96-140`).
5. Добавить `test/desktop_services_test.dart`-тест на проброс исключения
   (через подмену `hotKeyManager` невозможна — проверить хотя бы контракт
   applier'а) и обязательно ручной Windows-тест: занять `Ctrl+Alt+B`
   маленьким helper-процессом с `RegisterHotKey`, затем выбрать её в
   настройках.
6. Зафиксировать решение в `decisions.md` (ADR-017 «Патч
   hotkey_manager_windows: возврат ошибки RegisterHotKey»).

**Риски:** поддержка форка при обновлении Flutter/Windows; патч только для
Windows. Смягчение — минимальный diff, тест на ручную проверку, отметка в
TD/ADR.

### Вариант B: FFI-проба до регистрации

Проверять занятость самостоятельно через `user32.dll`:

```dart
// Только Windows. Эскиз, не готовый код.
final _user32 = DynamicLibrary.open('user32.dll');
final _registerHotKey = _user32.lookupFunction<
    Int32 Function(IntPtr hWnd, Int32 id, Uint32 fsModifiers, Uint32 vk),
    int Function(int hWnd, int id, int fsModifiers, int vk)>('RegisterHotKey');
final _unregisterHotKey = _user32.lookupFunction<
    Int32 Function(IntPtr hWnd, Int32 id),
    int Function(int hWnd, int id)>('UnregisterHotKey');

bool _probeFree(int vk, int modifiers) {
  const probeId = 0xB1; // не пересекается с id плагина
  final ok = _registerHotKey(0, probeId, modifiers, vk) != 0;
  if (ok) _unregisterHotKey(0, probeId);
  return ok;
}
```

- `hWnd = 0` привязывает регистрацию к потоку; Flutter-поток имеет message
  loop, `UnregisterHotKey` сразу освобождает комбинацию.
- Вызывать в `setQuickCaptureHotkey` до `hotKeyManager.register`; при `false`
  возвращать `false` без обращения к плагину.
- **Риски:** окно гонки между пробой и регистрацией; поведение при
  модификаторах/раскладке нужно проверить на всех поддерживаемых клавишах;
  сложнее сопровождать, чем патч.

### Вариант C: официально принять ограничение

Допустим только по решению владельца продукта:

- [ ] TD-27 перевести в `accepted` с обоснованием.
- [ ] Переформулировать критерий stage-02: «откат реализован и покрыт
      тестами; обнаружение занятости на Windows — TD-27».
- [ ] Убрать из ADR-016/отчёта утверждения о работающем откате при занятой
      комбинации.
- [ ] Добавить в UI/документацию предупреждение, что занятость не
      обнаруживается.
- [ ] Запросить PASS WITH COMMENTS вместо FAIL.

---

## R02-010 — backoff и защита от повторов toast (MINOR)

**Проблема.** При `show() == false` попытка и warning повторяются каждые 30 с
бесконечно; если toast показан, а `markReminderSent` не удался, toast
показывается повторно.

**Задача:**

- [ ] Ввести in-memory состояние попыток на задачу: `failures`, `nextAttemptAt`.
- [ ] Задержки: 30 с → 1 мин → 5 мин → 15 мин (далее 15 мин), лог только при
      первом сбое и при смене интервала.
- [ ] Если `show() == true`, а отметка не удалась — не показывать toast
      повторно, а повторять только `markReminderSent` (например, набор
      `_shownButUnmarked`).
- [ ] Сбрасывать состояние при успешной отметке/изменении `remind_at`/dispose.
- [ ] Тесты с failing notifier и fake clock: число вызовов `show` на тиках
      0/30 с/1 мин/5 мин/15 мин.

**Эскиз:**

```dart
final Map<int, int> _failures = {};
final Map<int, DateTime> _nextAttempt = {};

// в цикле checkNow для каждой задачи:
final next = _nextAttempt[task.id];
if (next != null && _clock().isBefore(next)) continue;

// при shown == false:
final n = (_failures[task.id] ?? 0) + 1;
_failures[task.id] = n;
_nextAttempt[task.id] = _clock().add(switch (n) {
  1 => const Duration(seconds: 30),
  2 => const Duration(minutes: 1),
  3 => const Duration(minutes: 5),
  _ => const Duration(minutes: 15),
});
if (n == 1) {
  AppLogger.w('ReminderScheduler: уведомление task-${task.id} не показано, '
      'повтор с backoff');
}
```

---

## R02-011 — не смешивать валюты в сводке дашборда (MINOR)

**Задача:**

- [ ] Добавить `static const String defaultCurrency = 'RUB'` в `FinanceDraft`
      (сейчас значение зашито в конструкторе) и использовать его как единый
      источник.
- [ ] Передавать валюту в `summary`:

      ```dart
      final summary = (await financeRepo.summary(
        from: month.start.toUtc(),
        to: month.end.toUtc(),
        currency: FinanceDraft.defaultCurrency,
      )).unwrap();
      ```

- [ ] Показать валюту в заголовке/подписи карточки доходов/расходов, чтобы
      цифры были однозначны.
- [ ] Тест: две операции в разных валютах → сводка учитывает только валюту
      по умолчанию (или, если выбрана разбивка, суммы по каждой валюте).
- [ ] Альтернатива, если нужна мультивалютность: `summary` по каждой валюте
      и отдельные строки на дашборде; тогда добавить ADR.

---

## R02-012 — `RefreshIndicator` должен ждать загрузку (NIT)

**Задача:**

- [ ] Сделать `_reload` возвращающим `Future<void>`:

      ```dart
      Future<void> _reload() async {
        final future = _load();
        setState(() => _future = future);
        try {
          await future;
        } on Object {
          // ошибку показывает FutureBuilder (ErrorState)
        }
      }
      ```

- [ ] `onRefresh: _reload`.
- [ ] Проверить, что при ошибке индикатор завершается и показывается
      `ErrorState`, а не «успешное» обновление.

---

## R02-013 — устаревший текст лога (NIT)

**Задача:**

- [ ] В `lib/main.dart:11,30` заменить «этап 0 — каркас» на нейтральное
      «Second Brain: приложение запущено» (или версию этапа).
- [ ] Проверить, что других упоминаний «этап 0» в логах/UI нет (`grep`).

---

## Общие требования к исправлениям

- Не менять публичные контракты без ADR; не выходить за stage-02.
- Каждая правка — с regression-тестом (кроме чисто текстовых NIT).
- Обновить `docs/stages/stage-02.md`, `docs/context.md`, `docs/INDEX.md`,
  `docs/tech-debt.md` (TD-27: статус/решение), при варианте A — добавить ADR.
- Прогнать: `flutter pub get --enforce-lockfile`, `flutter analyze
  --fatal-infos`, `flutter test`, `flutter build windows --debug`; приложить
  CI-run.
- Windows-сценарий R02-009 — обязательно вручную (CI не покрывает
  `RegisterHotKey`/GUI). Добавить его в чек-лист отчёта этапа.
- После исправлений запросить ревью №3; до вердикта без MAJOR stage-03 не
  начинать.

## Что ревьюер проверит в №3

1. Патч/решение R02-009 и ручной сценарий занятой комбинации.
2. Отсутствие повторных toast/лога при сбоях, тесты backoff.
3. Отсутствие смешивания валют, тест с двумя валютами.
4. `RefreshIndicator`, текст лога.
5. Соответствие документации факту (ADR-016, stage-02, TD-27, INDEX/context).
6. `analyze`/`test`/`build` и CI без расхождений.
