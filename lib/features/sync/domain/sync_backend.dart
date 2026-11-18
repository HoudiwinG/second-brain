import '../../../core/result/result.dart';
import 'sync_profile.dart';

/// Абстракция облачного/локального sync-бэкенда.
///
/// В stage-10 первая реализация — in-memory stub; OAuth/облако подключаются
/// позже без изменения UI и sync-сервиса.
abstract interface class SyncBackend {
  String get id;
  String get displayName;

  Future<Result<void>> push(SyncProfile profile, Map<String, Object?> snapshot);

  Future<Result<Map<String, Object?>?>> pull(SyncProfile profile);
}

/// Stub-бэкенд: хранит последний снимок в памяти процесса.
///
/// Нужен для проверки sync-flow без внешних credentials. Не является
/// облачным хранилищем и не переживает перезапуск приложения.
class StubSyncBackend implements SyncBackend {
  StubSyncBackend();

  final Map<String, Map<String, Object?>> _snapshots = {};

  @override
  String get id => 'stub';

  @override
  String get displayName => 'Local stub';

  @override
  Future<Result<void>> push(
    SyncProfile profile,
    Map<String, Object?> snapshot,
  ) async {
    _snapshots[profile.id] = snapshot;
    return const Result.success(null);
  }

  @override
  Future<Result<Map<String, Object?>?>> pull(SyncProfile profile) async {
    return Result.success(_snapshots[profile.id]);
  }
}
