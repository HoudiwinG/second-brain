/// Локальный профиль синхронизации/аккаунта.
///
/// В stage-10 профиль — локальная сущность без облачного логина; backend
/// подключается через интерфейс и может быть заменён на OAuth/облако.
class SyncProfile {
  const SyncProfile({
    required this.id,
    required this.displayName,
    required this.backendId,
    required this.isActive,
    required this.createdAt,
    this.lastSyncedAt,
  });

  final String id;
  final String displayName;
  final String backendId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastSyncedAt;

  SyncProfile copyWith({
    String? displayName,
    String? backendId,
    bool? isActive,
    DateTime? lastSyncedAt,
  }) => SyncProfile(
    id: id,
    displayName: displayName ?? this.displayName,
    backendId: backendId ?? this.backendId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'backend_id': backendId,
    'is_active': isActive,
    'created_at': createdAt.toUtc().toIso8601String(),
    'last_synced_at': lastSyncedAt?.toUtc().toIso8601String(),
  };

  static SyncProfile? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final id = raw['id'];
    final name = raw['display_name'];
    final backend = raw['backend_id'];
    final created = raw['created_at'];
    if (id is! String || name is! String || backend is! String) return null;
    final createdAt = DateTime.tryParse(created is String ? created : '');
    if (createdAt == null) return null;
    final last = raw['last_synced_at'];
    return SyncProfile(
      id: id,
      displayName: name,
      backendId: backend,
      isActive: raw['is_active'] == true,
      createdAt: createdAt.toUtc(),
      lastSyncedAt: last is String ? DateTime.tryParse(last)?.toUtc() : null,
    );
  }
}
