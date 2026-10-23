/// Данные системного напоминания.
class ReminderMessage {
  const ReminderMessage({
    required this.taskId,
    required this.title,
    required this.body,
  });

  final int taskId;
  final String title;
  final String body;
}
