import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/error/app_exception.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/features/reminders/application/reminder_notifier.dart';
import 'package:second_brain/features/reminders/application/reminder_scheduler.dart';
import 'package:second_brain/features/reminders/domain/reminder_message.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

class _RecordingNotifier implements ReminderNotifier {
  final List<ReminderMessage> messages = [];
  bool succeeds = true;
  bool throws = false;

  @override
  Future<bool> show(ReminderMessage message) async {
    messages.add(message);
    if (throws) throw StateError('тест: toast недоступен');
    return succeeds;
  }
}

/// Репозиторий, у которого можно смоделировать сбой отметки (R02-010).
class _FlakyMarkRepository extends DriftTasksRepository {
  _FlakyMarkRepository(super.db);

  bool failMarks = true;
  int markCalls = 0;

  @override
  Future<Result<void>> markReminderSent(int id, {required DateTime remindAt}) {
    markCalls += 1;
    if (failMarks) {
      return Future.value(
        Result<void>.failure(const DataException('тест: отметка не сохранена')),
      );
    }
    return super.markReminderSent(id, remindAt: remindAt);
  }
}

void main() {
  late AppDatabase db;
  late DriftTasksRepository repo;
  late _RecordingNotifier notifier;
  final now = DateTime.utc(2026, 10, 23, 12);
  late DateTime clockNow;

  setUp(() {
    db = InMemoryDbFactory.open();
    addTearDown(db.close);
    repo = DriftTasksRepository(db);
    notifier = _RecordingNotifier();
    clockNow = now;
  });

  ReminderScheduler scheduler({TasksRepository? repository}) =>
      ReminderScheduler(
        repository: () async => repository ?? repo,
        notifier: notifier,
        clock: () => clockNow,
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
      TaskDraft(title: 'Будущее', remindAt: now.add(const Duration(hours: 1))),
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

  test('не помечает sent, если notifier вернул false (R02-002)', () async {
    final task = (await repo.create(
      TaskDraft(
        title: 'Toast недоступен',
        remindAt: now.subtract(const Duration(minutes: 1)),
      ),
    )).unwrap();
    notifier.succeeds = false;

    final service = scheduler();
    addTearDown(service.dispose);

    await service.checkNow();

    expect(notifier.messages, hasLength(1));
    expect((await repo.getById(task.id)).unwrap()!.reminderSentAt, isNull);
    expect((await repo.dueReminders(now)).unwrap(), hasLength(1));
  });

  test('не помечает sent, если notifier бросил исключение', () async {
    final task = (await repo.create(
      TaskDraft(
        title: 'Ошибка toast',
        remindAt: now.subtract(const Duration(minutes: 1)),
      ),
    )).unwrap();
    notifier.throws = true;

    final service = scheduler();
    addTearDown(service.dispose);

    await service.checkNow();

    expect(notifier.messages, hasLength(1));
    expect((await repo.getById(task.id)).unwrap()!.reminderSentAt, isNull);
    expect((await repo.dueReminders(now)).unwrap(), hasLength(1));
  });

  test('backoff 30 с → 1 мин → 5 мин → 15 мин (R02-010)', () async {
    await repo.create(
      TaskDraft(
        title: 'Toast недоступен',
        remindAt: now.subtract(const Duration(minutes: 10)),
      ),
    );
    notifier.succeeds = false;

    final service = scheduler();
    addTearDown(service.dispose);

    await service.checkNow();
    expect(notifier.messages, hasLength(1));

    // До 30 секунд повтор не выполняется.
    clockNow = now.add(const Duration(seconds: 29));
    await service.checkNow();
    expect(notifier.messages, hasLength(1));

    clockNow = now.add(const Duration(seconds: 30));
    await service.checkNow();
    expect(notifier.messages, hasLength(2));

    // Следующий интервал — 1 минута от второй попытки.
    clockNow = now.add(const Duration(seconds: 30 + 59));
    await service.checkNow();
    expect(notifier.messages, hasLength(2));

    clockNow = now.add(const Duration(seconds: 30 + 60));
    await service.checkNow();
    expect(notifier.messages, hasLength(3));

    // Далее 5 минут.
    clockNow = now.add(const Duration(seconds: 30 + 60 + 299));
    await service.checkNow();
    expect(notifier.messages, hasLength(3));

    clockNow = now.add(const Duration(seconds: 30 + 60 + 300));
    await service.checkNow();
    expect(notifier.messages, hasLength(4));

    // Далее 15 минут.
    clockNow = now.add(const Duration(seconds: 30 + 60 + 300 + 899));
    await service.checkNow();
    expect(notifier.messages, hasLength(4));

    clockNow = now.add(const Duration(seconds: 30 + 60 + 300 + 900));
    await service.checkNow();
    expect(notifier.messages, hasLength(5));

    // Интервал стабилизировался на 15 минутах.
    clockNow = now.add(const Duration(seconds: 30 + 60 + 300 + 900 + 899));
    await service.checkNow();
    expect(notifier.messages, hasLength(5));

    clockNow = now.add(const Duration(seconds: 30 + 60 + 300 + 900 + 900));
    await service.checkNow();
    expect(notifier.messages, hasLength(6));
  });

  test('после показа toast повторяется только отметка (R02-010)', () async {
    final flaky = _FlakyMarkRepository(db);
    final task = (await repo.create(
      TaskDraft(
        title: 'Показан, но не отмечен',
        remindAt: now.subtract(const Duration(minutes: 1)),
      ),
    )).unwrap();
    final service = scheduler(repository: flaky);
    addTearDown(service.dispose);

    await service.checkNow();
    expect(notifier.messages, hasLength(1));
    expect(flaky.markCalls, 1);
    expect((await repo.getById(task.id)).unwrap()!.reminderSentAt, isNull);

    // В пределах backoff повторной попытки нет.
    await service.checkNow();
    expect(notifier.messages, hasLength(1));
    expect(flaky.markCalls, 1);

    // Через 30 секунд — только отметка, без второго toast.
    clockNow = now.add(const Duration(seconds: 30));
    await service.checkNow();
    expect(notifier.messages, hasLength(1));
    expect(flaky.markCalls, 2);

    // Отметка восстановилась: toast больше не повторяется, задача закрыта.
    flaky.failMarks = false;
    clockNow = now.add(const Duration(seconds: 30 + 60));
    await service.checkNow();

    expect(notifier.messages, hasLength(1));
    expect(flaky.markCalls, 3);
    expect((await repo.getById(task.id)).unwrap()!.reminderSentAt, isNotNull);
    expect((await repo.dueReminders(clockNow)).unwrap(), isEmpty);

    await service.checkNow();
    expect(notifier.messages, hasLength(1));
    expect(flaky.markCalls, 3);
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
