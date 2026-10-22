import '../../../core/result/result.dart';

/// Заметка — основная текстовая сущность.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.categoryId,
    required this.tags,
    required this.isPrivateForLlm,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final String title;
  final String body;
  final int? categoryId;
  final List<String> tags;

  /// true — заметку запрещено отправлять во внешнюю LLM.
  final bool isPrivateForLlm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// Данные для создания/полного обновления заметки.
class NoteDraft {
  const NoteDraft({
    required this.title,
    this.body = '',
    this.categoryId,
    this.tags = const [],
    this.isPrivateForLlm = false,
  });

  final String title;
  final String body;
  final int? categoryId;
  final List<String> tags;
  final bool isPrivateForLlm;
}

/// Контракт хранилища заметок.
abstract interface class NotesRepository {
  Future<Result<List<Note>>> list({
    bool includeDeleted = false,
    bool forLlm = false,
  });

  Future<Result<Note?>> getById(int id, {bool includeDeleted = false});

  Future<Result<Note>> create(NoteDraft draft);

  Future<Result<Note>> update(int id, NoteDraft draft);

  /// Мягкое удаление: запись остаётся в БД, но скрыта из выборок и FTS.
  Future<Result<void>> softDelete(int id);

  Future<Result<void>> restore(int id);
}
