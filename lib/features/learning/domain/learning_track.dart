import '../../../core/result/result.dart';
import 'learning_session.dart';

/// Статус шага roadmap.
enum LearningStepStatus {
  todo('todo'),
  inProgress('in_progress'),
  done('done');

  const LearningStepStatus(this.dbValue);

  final String dbValue;

  static LearningStepStatus fromDb(String raw) => LearningStepStatus.values
      .firstWhere((value) => value.dbValue == raw, orElse: () => todo);
}

/// Шаг roadmap. Хранится внутри JSON-поля трека.
class LearningStep {
  const LearningStep({
    required this.id,
    required this.title,
    this.description = '',
    this.status = LearningStepStatus.todo,
  });

  final String id;
  final String title;
  final String description;
  final LearningStepStatus status;

  LearningStep copyWith({
    String? title,
    String? description,
    LearningStepStatus? status,
  }) => LearningStep(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.dbValue,
  };

  static LearningStep? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final title = raw['title'];
    if (title is! String || title.trim().isEmpty) return null;
    final id = raw['id'];
    return LearningStep(
      id: id is String && id.isNotEmpty ? id : newLearningStepId(),
      title: title.trim(),
      description: raw['description'] is String
          ? (raw['description']! as String).trim()
          : '',
      status: raw['status'] is String
          ? LearningStepStatus.fromDb(raw['status']! as String)
          : LearningStepStatus.todo,
    );
  }
}

var _stepSequence = 0;

/// Уникальный id шага в рамках трека.
String newLearningStepId() {
  _stepSequence++;
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '_${_stepSequence.toRadixString(36)}';
}

/// Трек обучения: цель, roadmap и пользовательские поля.
class LearningTrack {
  const LearningTrack({
    required this.id,
    required this.title,
    required this.goal,
    required this.steps,
    required this.customFields,
    required this.isPrivateForLlm,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final String title;
  final String goal;
  final List<LearningStep> steps;
  final Map<String, String> customFields;

  /// true — трек и его цель/шаги нельзя отправлять в LLM.
  final bool isPrivateForLlm;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  int get completedSteps =>
      steps.where((step) => step.status == LearningStepStatus.done).length;

  double get progress => steps.isEmpty ? 0 : completedSteps / steps.length;

  LearningTrack copyWith({
    String? title,
    String? goal,
    List<LearningStep>? steps,
    Map<String, String>? customFields,
    bool? isPrivateForLlm,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => LearningTrack(
    id: id,
    title: title ?? this.title,
    goal: goal ?? this.goal,
    steps: steps ?? this.steps,
    customFields: customFields ?? this.customFields,
    isPrivateForLlm: isPrivateForLlm ?? this.isPrivateForLlm,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}

/// Данные создания/редактирования трека.
class LearningTrackDraft {
  const LearningTrackDraft({
    required this.title,
    this.goal = '',
    this.steps = const [],
    this.customFields = const {},
    this.isPrivateForLlm = false,
  });

  final String title;
  final String goal;
  final List<LearningStep> steps;
  final Map<String, String> customFields;
  final bool isPrivateForLlm;
}

/// Хранилище треков и сессий обучения.
abstract interface class LearningRepository {
  Future<Result<List<LearningTrack>>> listTracks({
    bool includeDeleted = false,
    bool forLlm = false,
  });

  Future<Result<LearningTrack?>> getTrack(
    int id, {
    bool includeDeleted = false,
  });

  Future<Result<LearningTrack>> createTrack(LearningTrackDraft draft);

  Future<Result<LearningTrack>> updateTrack(int id, LearningTrackDraft draft);

  Future<Result<LearningTrack>> setSteps(int id, List<LearningStep> steps);

  Future<Result<LearningTrack>> setStepStatus(
    int trackId,
    String stepId,
    LearningStepStatus status,
  );

  Future<Result<void>> softDeleteTrack(int id);

  Future<Result<List<LearningSession>>> listSessions(int trackId);

  Future<Result<LearningSession>> addSession(LearningSessionDraft draft);

  Future<Result<void>> deleteSession(int id);
}
