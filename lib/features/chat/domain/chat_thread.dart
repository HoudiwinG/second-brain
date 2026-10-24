/// Тред чата. Хранится локально и доступен офлайн.
final class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.providerConfigId,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  final int id;
  final String title;
  final int? providerConfigId;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

/// Данные нового треда.
final class ChatThreadDraft {
  const ChatThreadDraft({
    required this.title,
    required this.providerConfigId,
    required this.model,
  });

  final String title;
  final int? providerConfigId;
  final String model;
}
