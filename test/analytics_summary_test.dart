import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/analytics/domain/analytics_summary.dart';
import 'package:second_brain/features/finance/domain/finance_transaction.dart';
import 'package:second_brain/features/ideas/domain/idea_entry.dart';
import 'package:second_brain/features/learning/domain/learning_session.dart';
import 'package:second_brain/features/learning/domain/learning_track.dart';
import 'package:second_brain/features/mail/domain/mail_message.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

TaskItem _task({
  required int id,
  required TaskStatus status,
  DateTime? dueAt,
}) => TaskItem(
  id: id,
  title: 'Task $id',
  description: '',
  priority: TaskPriority.normal,
  dueAt: dueAt,
  remindAt: null,
  reminderSentAt: null,
  status: status,
  tags: const [],
  linkedNoteId: null,
  isPrivateForLlm: false,
  recurrence: null,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  deletedAt: null,
);

void main() {
  test('аналитика считает задачи, обучение и финансы', () {
    final summary = buildAnalyticsSummary(
      notes: const <Note>[],
      ideas: const <IdeaEntry>[],
      tasks: [
        _task(id: 1, status: TaskStatus.todo, dueAt: DateTime.utc(2020, 1, 1)),
        _task(id: 2, status: TaskStatus.done),
      ],
      tracks: const <LearningTrack>[],
      sessions: [
        LearningSession(
          id: 1,
          trackId: 1,
          durationMinutes: 30,
          notes: '',
          date: DateTime.utc(2026, 1, 1),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      mail: const <MailMessage>[],
      finance: [
        FinanceTransaction(
          id: 1,
          amount: 100,
          currency: 'RUB',
          type: FinanceTransactionType.income,
          category: null,
          account: null,
          date: DateTime.utc(2026, 1, 1),
          note: null,
          isPrivateForLlm: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          deletedAt: null,
        ),
        FinanceTransaction(
          id: 2,
          amount: 40,
          currency: 'RUB',
          type: FinanceTransactionType.expense,
          category: 'Food',
          account: null,
          date: DateTime.utc(2026, 1, 2),
          note: null,
          isPrivateForLlm: false,
          createdAt: DateTime.utc(2026, 1, 2),
          updatedAt: DateTime.utc(2026, 1, 2),
          deletedAt: null,
        ),
      ],
      now: DateTime.utc(2026, 1, 3),
    );

    expect(summary.tasksTotal, 2);
    expect(summary.tasksOpen, 1);
    expect(summary.tasksDone, 1);
    expect(summary.tasksOverdue, 1);
    expect(summary.learningSessions, 1);
    expect(summary.learningMinutes, 30);
    expect(summary.income, 100);
    expect(summary.expense, 40);
    expect(summary.balance, 60);
    expect(summary.topExpenses.single.key, 'Food');
  });
}
