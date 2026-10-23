import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../tasks/domain/task_item.dart';
import '../domain/reminder_message.dart';
import 'reminder_notifier.dart';

/// Периодически проверяет задачи с наступившим `remind_at`.
///
/// Сервис не зависит от UI и плагинов напрямую: репозиторий и notifier
/// инжектируются, поэтому логика проверяется unit-тестами.
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

  final Future<TasksRepository> Function() _repository;
  final ReminderNotifier _notifier;
  final DateTime Function() _clock;
  final Duration interval;

  Timer? _timer;
  var _checking = false;
  var _disposed = false;

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
      final due = (await repository.dueReminders(_clock().toUtc())).unwrap();
      for (final task in due) {
        await _notify(repository, task);
      }
    } on Object catch (e, s) {
      AppLogger.e('ReminderScheduler: проверка напоминаний не удалась', e, s);
    } finally {
      _checking = false;
    }
  }

  Future<void> _notify(TasksRepository repository, TaskItem task) async {
    final remindAt = task.remindAt;
    if (remindAt == null) return;
    try {
      final shown = await _notifier.show(
        ReminderMessage(
          taskId: task.id,
          title: task.title,
          body: task.description,
        ),
      );
      if (!shown) {
        // Не помечаем отправленным: при следующем тике попробуем снова.
        AppLogger.w(
          'ReminderScheduler: уведомление task-${task.id} не показано, '
          'повтор при следующем тике',
        );
        return;
      }
      final marked = await repository.markReminderSent(
        task.id,
        remindAt: remindAt,
      );
      marked.when(
        success: (_) {},
        failure: (error) => AppLogger.appError(error),
      );
    } on Object catch (e, s) {
      // Не помечаем отправленным: при следующем тике попробуем снова.
      AppLogger.e(
        'ReminderScheduler: не удалось отправить напоминание task-${task.id}',
        e,
        s,
      );
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
