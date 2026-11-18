import 'dart:async';

import '../../data/backup/backup_service.dart';
import '../../features/sync/data/sync_profile_repository.dart';
import '../../features/sync/domain/sync_backend.dart';
import '../../features/sync/domain/sync_profile.dart';
import '../error/app_exception.dart';
import '../result/result.dart';

/// Состояние облачной синхронизации (stub на stage-10).
enum SyncStatus { disabled, idle, syncing, error }

/// Контракт sync-сервиса: push/pull снимка для локального профиля.
abstract interface class SyncService {
  Future<Result<void>> push(SyncProfile profile);

  Future<Result<void>> pull(SyncProfile profile);

  Stream<SyncStatus> get status;
}

/// Локально-первичная реализация: backup-snapshot → backend → restore.
///
/// В первой итерации stage-10 backend — [StubSyncBackend], поэтому данные
/// живут в памяти процесса. OAuth/облачный backend подключается через
/// [SyncBackend] без изменения UI.
class LocalSyncService implements SyncService {
  LocalSyncService({
    required this.backup,
    required this.backend,
    required this.profiles,
  });

  final BackupService backup;
  final SyncBackend backend;
  final SyncProfileRepository profiles;
  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = SyncStatus.idle;

  @override
  Stream<SyncStatus> get status => _status.stream;

  void _emit(SyncStatus value) {
    _current = value;
    if (!_status.isClosed) _status.add(value);
  }

  @override
  Future<Result<void>> push(SyncProfile profile) async {
    _emit(SyncStatus.syncing);
    final snapshot = await backup.buildSnapshot();
    if (snapshot is Failure<Map<String, Object?>>) {
      _emit(SyncStatus.error);
      return Result.failure(snapshot.error);
    }
    final pushed = await backend.push(
      profile,
      (snapshot as Success<Map<String, Object?>>).value,
    );
    if (pushed is Failure<void>) {
      _emit(SyncStatus.error);
      return Result.failure(pushed.error);
    }
    await profiles.markSynced(profile.id, DateTime.now().toUtc());
    _emit(SyncStatus.idle);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> pull(SyncProfile profile) async {
    _emit(SyncStatus.syncing);
    final pulled = await backend.pull(profile);
    if (pulled is Failure<Map<String, Object?>?>) {
      _emit(SyncStatus.error);
      return Result.failure(pulled.error);
    }
    final snapshot = (pulled as Success<Map<String, Object?>?>).value;
    if (snapshot == null) {
      _emit(SyncStatus.error);
      return const Result.failure(
        ValidationException('SyncService: на backend нет снимка'),
      );
    }
    final restored = await backup.restoreSnapshot(snapshot);
    if (restored is Failure<void>) {
      _emit(SyncStatus.error);
      return Result.failure(restored.error);
    }
    await profiles.markSynced(profile.id, DateTime.now().toUtc());
    _emit(SyncStatus.idle);
    return const Result.success(null);
  }

  SyncStatus get currentStatus => _current;
}
