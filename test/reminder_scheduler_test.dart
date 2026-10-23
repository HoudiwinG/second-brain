import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/features/reminders/application/reminder_notifier.dart';
import 'package:second_brain/features/reminders/application/reminder_scheduler.dart';
import 'package:second_brain/features/reminders/domain/reminder_message.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

class _RecordingNotifier implements ReminderNotifier {
  final List<ReminderMessage> messages = [];

  @override
  Future<void> show(ReminderMessage message) async {
    messages.add(message);
  }
}

void main() {
  late DriftTasksRepository repo;
  late _RecordingNotifier notifier;
  final now = DateTime.utc(2026, 10, 23, 12);

  setUp(() {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    repo = DriftTasksRepository(db);
    notifier = _RecordingNotifier();
  });

  ReminderScheduler scheduler() => ReminderScheduler(
    repository: () async => repo,
    notifier: notifier,
    clock: () => now,
  );

  test('отправляет только наступившие напоминания один раз', () async {
    final past = (await repo.create(
      TaskDraft(
        title: 'Позвонить',
        description: 'Клиент',
        remindAt: now.subtract(const Duration(minutes: 10)),
      ),
    )).unwrap();
    await repo.create(
      TaskDraft(
        title: 'Будущее',
        remindAt: now.add(const Duration(hours: 1)),
      ),
    );
    final done = (await repo.create(
      TaskDraft(
        title: 'Готово',
        remindAt: now.subtract(const Duration(hours: 1)),
      ),
    )).unwrap();
    await repo.setStatus(done.id, TaskStatus.done);

    final service = scheduler();
    addTearDown(service.dispose);

    await service.checkNow();
    await service.checkNow();

    expect(notifier.messages, hasLength(1));
    expect(notifier.messages.single.taskId, past.id);
    expect(notifier.messages.single.title, 'Позвонить');
    expect((await repo.dueReminders(now)).unwrap(), isEmpty);
  });

  test('изменение remind_at снова разрешает напоминание', () async {
    final task = (await repo.create(
      TaskDraft(
        title: 'Отчёт',
        remindAt: now.subtract(const Duration(hours: 2)),
      ),
    )).unwrap();
    final service = scheduler();
    addTearDown(service.dispose);

    await service.checkNow();
    expect(notifier.messages, hasLength(1));

    final rescheduled = now.subtract(const Duration(minutes: 5));
    await repo.update(
      task.id,
      TaskDraft(title: task.title, remindAt: rescheduled),
    );

    final due = (await repo.dueReminders(now)).unwrap();
    expect(due, hasLength(1));
    expect(due.single.remindAt!.toUtc(), rescheduled);

    await service.checkNow();
    expect(notifier.messages, hasLength(2));
    expect(notifier.messages.last.taskId, task.id);
  });

  test('markReminderSent не помечает задачу при другом remind_at', () async {
    final first = now.subtract(const Duration(hours: 2));
    final second = now.subtract(const Duration(hours: 1));
    final task = (await repo.create(
      TaskDraft(title: 'Проверка', remindAt: first),
    )).unwrap();

    await repo.update(task.id, TaskDraft(title: task.title, remindAt: second));
    (await repo.markReminderSent(task.id, remindAt: first)).unwrap();

    final due = (await repo.dueReminders(now)).unwrap();
    expect(due, hasLength(1));

    (await repo.markReminderSent(task.id, remindAt: second)).unwrap();
    expect((await repo.dueReminders(now)).unwrap(), isEmpty);
  });
}
