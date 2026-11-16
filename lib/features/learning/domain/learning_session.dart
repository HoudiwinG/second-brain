/// Сессия обучения по треку.
class LearningSession {
  const LearningSession({
    required this.id,
    required this.trackId,
    required this.durationMinutes,
    required this.notes,
    required this.date,
    required this.createdAt,
  });

  final int id;
  final int trackId;

  /// Длительность в минутах.
  final int durationMinutes;

  final String notes;

  /// Дата занятия (без привязки к часовому поясу в UI).
  final DateTime date;
  final DateTime createdAt;
}

/// Данные для добавления сессии.
class LearningSessionDraft {
  const LearningSessionDraft({
    required this.trackId,
    required this.durationMinutes,
    this.notes = '',
    required this.date,
  });

  final int trackId;
  final int durationMinutes;
  final String notes;
  final DateTime date;
}
