import '../../finance/domain/finance_transaction.dart';
import '../../ideas/domain/idea_entry.dart';
import '../../learning/domain/learning_session.dart';
import '../../learning/domain/learning_track.dart';
import '../../mail/domain/mail_message.dart';
import '../../notes/domain/note.dart';
import '../../tasks/domain/task_item.dart';

/// Сводка для экрана аналитики. Чистая функция, без UI и сети.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.notes,
    required this.ideas,
    required this.tasksTotal,
    required this.tasksOpen,
    required this.tasksDone,
    required this.tasksOverdue,
    required this.learningTracks,
    required this.learningSessions,
    required this.learningMinutes,
    required this.mailMessages,
    required this.income,
    required this.expense,
    required this.transactions,
    required this.expenseByCategory,
  });

  final int notes;
  final int ideas;
  final int tasksTotal;
  final int tasksOpen;
  final int tasksDone;
  final int tasksOverdue;
  final int learningTracks;
  final int learningSessions;
  final int learningMinutes;
  final int mailMessages;
  final double income;
  final double expense;
  final int transactions;
  final Map<String, double> expenseByCategory;

  double get balance => income - expense;

  List<MapEntry<String, double>> get topExpenses {
    final entries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }
}

AnalyticsSummary buildAnalyticsSummary({
  required List<Note> notes,
  required List<IdeaEntry> ideas,
  required List<TaskItem> tasks,
  required List<LearningTrack> tracks,
  required List<LearningSession> sessions,
  required List<MailMessage> mail,
  required List<FinanceTransaction> finance,
  DateTime? now,
}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final open = tasks.where(
    (task) =>
        !task.isDeleted &&
        task.status != TaskStatus.done &&
        task.status != TaskStatus.cancelled,
  );
  final overdue = open.where((task) {
    final at = task.dueAt ?? task.remindAt;
    return at != null && at.isBefore(reference);
  }).length;
  final income = finance
      .where((item) => item.type == FinanceTransactionType.income)
      .fold<double>(0, (sum, item) => sum + item.amount);
  final expense = finance
      .where((item) => item.type == FinanceTransactionType.expense)
      .fold<double>(0, (sum, item) => sum + item.amount);
  final byCategory = <String, double>{};
  for (final item in finance) {
    if (item.type != FinanceTransactionType.expense) continue;
    final category = item.category?.trim();
    final key = category == null || category.isEmpty ? '—' : category;
    byCategory[key] = (byCategory[key] ?? 0) + item.amount;
  }
  return AnalyticsSummary(
    notes: notes.where((note) => !note.isDeleted).length,
    ideas: ideas.where((idea) => !idea.isDeleted).length,
    tasksTotal: tasks.where((task) => !task.isDeleted).length,
    tasksOpen: open.length,
    tasksDone: tasks
        .where((task) => !task.isDeleted && task.status == TaskStatus.done)
        .length,
    tasksOverdue: overdue,
    learningTracks: tracks.where((track) => track.deletedAt == null).length,
    learningSessions: sessions.length,
    learningMinutes: sessions.fold<int>(
      0,
      (sum, session) => sum + session.durationMinutes,
    ),
    mailMessages: mail.length,
    income: income,
    expense: expense,
    transactions: finance.length,
    expenseByCategory: byCategory,
  );
}
