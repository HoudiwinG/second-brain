import 'dart:convert';
import 'dart:math';

import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/settings_repository.dart';
import '../domain/sync_profile.dart';

/// Локальные профили sync в `app_settings` (JSON), без секретов.
class SyncProfileRepository {
  SyncProfileRepository(this._settings, {Random? random})
    : _random = random ?? Random.secure();

  static const _profilesKey = 'sync.profiles';

  final SettingsRepository _settings;
  final Random _random;

  Future<Result<List<SyncProfile>>> list() async {
    final raw = await _settings.get(_profilesKey);
    if (raw is Failure<String?>) return Result.failure(raw.error);
    final value = (raw as Success<String?>).value;
    if (value == null || value.isEmpty) return const Result.success([]);
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const Result.failure(
          DataException('SyncProfileRepository: некорректный JSON'),
        );
      }
      final profiles = <SyncProfile>[];
      for (final item in decoded) {
        final profile = SyncProfile.fromJson(item);
        if (profile != null) profiles.add(profile);
      }
      return Result.success(profiles);
    } on FormatException catch (error) {
      return Result.failure(
        DataException('SyncProfileRepository: некорректный JSON', cause: error),
      );
    }
  }

  Future<Result<SyncProfile>> create(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      return const Result.failure(
        ValidationException('SyncProfileRepository: имя профиля пустое'),
      );
    }
    final current = await list();
    if (current is Failure<List<SyncProfile>>) {
      return Result.failure(current.error);
    }
    final profiles = (current as Success<List<SyncProfile>>).value;
    final profile = SyncProfile(
      id:
          'profile_${DateTime.now().microsecondsSinceEpoch}_'
          '${_random.nextInt(1 << 32)}',
      displayName: name,
      backendId: 'stub',
      isActive: profiles.isEmpty,
      createdAt: DateTime.now().toUtc(),
    );
    final saved = await _save([...profiles, profile]);
    if (saved is Failure<void>) return Result.failure(saved.error);
    return Result.success(profile);
  }

  Future<Result<void>> setActive(String id) async {
    final current = await list();
    if (current is Failure<List<SyncProfile>>) {
      return Result.failure(current.error);
    }
    final existing = (current as Success<List<SyncProfile>>).value;
    if (!existing.any((profile) => profile.id == id)) {
      return Result.failure(
        ValidationException('SyncProfileRepository: профиль $id не найден'),
      );
    }
    final profiles = [
      for (final profile in existing)
        profile.id == id
            ? profile.copyWith(isActive: true)
            : profile.copyWith(isActive: false),
    ];
    return _save(profiles);
  }

  Future<Result<void>> markSynced(String id, DateTime at) async {
    final current = await list();
    if (current is Failure<List<SyncProfile>>) {
      return Result.failure(current.error);
    }
    final profiles = [
      for (final profile in (current as Success<List<SyncProfile>>).value)
        profile.id == id ? profile.copyWith(lastSyncedAt: at) : profile,
    ];
    return _save(profiles);
  }

  Future<Result<void>> delete(String id) async {
    final current = await list();
    if (current is Failure<List<SyncProfile>>) {
      return Result.failure(current.error);
    }
    final profiles = (current as Success<List<SyncProfile>>).value
        .where((profile) => profile.id != id)
        .toList();
    if (profiles.isNotEmpty && !profiles.any((p) => p.isActive)) {
      profiles[0] = profiles[0].copyWith(isActive: true);
    }
    return _save(profiles);
  }

  Future<Result<void>> _save(List<SyncProfile> profiles) {
    return _settings.set(
      _profilesKey,
      jsonEncode([for (final profile in profiles) profile.toJson()]),
    );
  }
}
