import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../tasks/domain/task_item.dart';
import '../domain/reminder_message.dart';
import 'reminder_notifier.dart';

/// Периодически проверяет задачи с наступившим `remind_at`.
///
/// Сервис не зависит от UI и плагинов напрямую: репозиторий и notifier
/// инжектируются, поэтому логика проверяется unit-тестами.
///
/// Повторные неудачи не спамят пользователя и лог: после первого сбоя попытка
/// откладывается по схеме 30 с → 1 мин → 5 мин → 15 мин (R02-010). Если toast
/// уже показан, но `reminder_sent_at` записать не удалось, повторяется только
/// отметка — второй toast не показывается.
class ReminderScheduler {
  factory ReminderScheduler({
    required Future<TasksRepository> Function() repository,
    required ReminderNotifier notifier,
    DateTime Function()? clock,
    Duration interval = const Duration(seconds: 30),
  }) {
    return ReminderScheduler._(
      repository,
      notifier,
      clock ?? DateTime.now,
      interval,
    );
  }

  ReminderScheduler._(
    this._repository,
    this._notifier,
    this._clock,
    this.interval,
  );

  /// Задержки повторов после неудачного показа. Последнее значение
  /// повторяется, пока попытка не увенчается успехом.
  static const List<Duration> _retryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  final Future<TasksRepository> Function() _repository;
  final ReminderNotifier _notifier;
  final DateTime Function() _clock;
  final Duration interval;

  Timer? _timer;
  var _checking = false;
  var _disposed = false;

  /// In-memory состояние попыток по id задачи (R02-010).
  final Map<int, _ReminderAttempt> _attempts = {};

  bool get isRunning => _timer != null;

  /// Запускает немедленную проверку и периодический таймер.
  Future<void> start() async {
    if (_disposed || _timer != null) return;
    await checkNow();
    if (_disposed) return;
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow()));
  }

  /// Проверяет наступившие напоминания вручную (используется тестами).
  Future<void> checkNow() async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      final repository = await _repository();
      final now = _clock().toUtc();
      final due = (await repository.dueReminders(now)).unwrap();
      for (final task in due) {
        await _notify(repository, task, now);
      }
    } on Object catch (e, s) {
      AppLogger.e('ReminderScheduler: проверка напоминаний не удалась', e, s);
    } finally {
      _checking = false;
    }
  }

  Future<void> _notify(
    TasksRepository repository,
    TaskItem task,
    DateTime now,
  ) async {
    final remindAt = task.remindAt;
    if (remindAt == null) return;
    final remindAtUtc = remindAt.toUtc();

    // Если пользователь перенёс напоминание, состояние старой попытки
    // недействительно: новое время должно сработать независимо от backoff.
    final existing = _attempts[task.id];
    if (existing != null && existing.remindAt != remindAtUtc) {
      _attempts.remove(task.id);
    }
    var attempt = _attempts[task.id];

    final nextAttemptAt = attempt?.nextAttemptAt;
    if (nextAttemptAt != null && now.isBefore(nextAttemptAt)) {
      return;
    }

    // Toast уже показан, но отметка не сохранилась: не показываем его снова,
    // повторяем только markReminderSent.
    if (attempt?.shown == true) {
      await _markOnly(repository, task, attempt!, now);
      return;
    }

    attempt ??= _ReminderAttempt(remindAtUtc);
    _attempts[task.id] = attempt;

    final bool shown;
    try {
      shown = await _notifier.show(
        ReminderMessage(
          taskId: task.id,
          title: task.title,
          body: task.description,
        ),
      );
    } on Object catch (e, s) {
      if (attempt.failures == 0) {
        AppLogger.e(
          'ReminderScheduler: не удалось показать напоминание task-${task.id}',
          e,
          s,
        );
      }
      _scheduleRetry(task.id, attempt, now, reason: 'toast недоступен');
      return;
    }

    if (!shown) {
      _scheduleRetry(task.id, attempt, now, reason: 'toast не показан');
      return;
    }

    // С этого момента toast считается доставленным: повторять его нельзя,
    // даже если запись reminder_sent_at не удалась.
    attempt.shown = true;
    await _markOnly(repository, task, attempt, now);
  }

  Future<void> _markOnly(
    TasksRepository repository,
    TaskItem task,
    _ReminderAttempt attempt,
    DateTime now,
  ) async {
    try {
      final marked = await repository.markReminderSent(
        task.id,
        remindAt: attempt.remindAt,
      );
      final success = marked.when<bool>(
        success: (_) => true,
        failure: (error) {
          AppLogger.appError(error);
          return false;
        },
      );
      if (success) {
        _attempts.remove(task.id);
        AppLogger.d(
          'ReminderScheduler: напоминание task-${task.id} отмечено отправленным',
        );
        return;
      }
    } on Object catch (e, s) {
      if (attempt.failures == 0) {
        AppLogger.e(
          'ReminderScheduler: не удалось отметить напоминание task-${task.id}',
          e,
          s,
        );
      }
    }
    _scheduleRetry(task.id, attempt, now, reason: 'отметка не сохранена');
  }

  /// Планирует повтор и логирует только первый сбой и смену интервала.
  void _scheduleRetry(
    int taskId,
    _ReminderAttempt attempt,
    DateTime now, {
    required String reason,
  }) {
    attempt.failures += 1;
    final index = attempt.failures >= _retryDelays.length
        ? _retryDelays.length - 1
        : attempt.failures - 1;
    final delay = _retryDelays[index];
    attempt.nextAttemptAt = now.add(delay);

    // Первые четыре сбоя меняют интервал — их полезно видеть в логе.
    // Дальше интервал постоянный, и повторные сообщения были бы шумом.
    if (attempt.failures <= _retryDelays.length) {
      AppLogger.w(
        'ReminderScheduler: напоминание task-$taskId не доставлено '
        '($reason), повтор через ${delay.inSeconds} с',
      );
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _attempts.clear();
  }
}

/// Состояние доставки одного напоминания в памяти процесса.
class _ReminderAttempt {
  _ReminderAttempt(this.remindAt);

  /// Время напоминания, к которому относится попытка (UTC).
  final DateTime remindAt;

  /// Сколько раз подряд не удалось показать/отметить напоминание.
  int failures = 0;

  /// Раньше этого времени повтор не выполняется.
  DateTime? nextAttemptAt;

  /// Toast уже показан; повторяется только запись [reminderSentAt].
  bool shown = false;
}
