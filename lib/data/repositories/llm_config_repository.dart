import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../../core/secrets/secret_store.dart';
import '../../features/llm/domain/llm_provider_config.dart';
import '../../features/llm/domain/llm_provider_type.dart';
import '../db/app_database.dart' as db;
import 'repository_guard.dart';

/// Конфигурации LLM-провайдеров и их API-ключи.
///
/// Ключи никогда не пишутся в БД: [LlmProviderConfig.secretRef] указывает
/// на запись в [SecretStore] (secure storage).
abstract interface class LlmConfigRepository {
  Future<Result<List<LlmProviderConfig>>> list();

  Future<Result<LlmProviderConfig?>> getById(int id);

  Future<Result<LlmProviderConfig?>> getDefault();

  Future<Result<LlmProviderConfig>> create(LlmConfigDraft draft);

  Future<Result<LlmProviderConfig>> update(int id, LlmConfigDraft draft);

  Future<Result<void>> delete(int id);

  Future<Result<void>> setDefault(int id);

  /// Читает API-ключ для конфигурации; null — ключ не задан.
  Future<Result<String?>> readApiKey(int id);
}

/// Drift + secure storage реализация.
final class DriftLlmConfigRepository implements LlmConfigRepository {
  DriftLlmConfigRepository(this._db, this._secrets, {Random? random})
    : _random = random ?? Random.secure();

  final db.AppDatabase _db;
  final SecretStore _secrets;
  final Random _random;

  @override
  Future<Result<List<LlmProviderConfig>>> list() {
    return RepositoryGuard.guard('LlmConfigRepository.list', () async {
      final rows =
          await (_db.select(_db.llmProviderConfigs)..orderBy([
                (t) => OrderingTerm.desc(t.isDefault),
                (t) => OrderingTerm.desc(t.updatedAt),
              ]))
              .get();
      return [for (final row in rows) _config(row)];
    });
  }

  @override
  Future<Result<LlmProviderConfig?>> getById(int id) {
    return RepositoryGuard.guard('LlmConfigRepository.getById', () async {
      final row = await (_db.select(
        _db.llmProviderConfigs,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _config(row);
    });
  }

  @override
  Future<Result<LlmProviderConfig?>> getDefault() {
    return RepositoryGuard.guard('LlmConfigRepository.getDefault', () async {
      final row = await (_db.select(
        _db.llmProviderConfigs,
      )..where((t) => t.isDefault.equals(true))).getSingleOrNull();
      return row == null ? null : _config(row);
    });
  }

  @override
  Future<Result<LlmProviderConfig>> create(LlmConfigDraft draft) {
    return RepositoryGuard.guard('LlmConfigRepository.create', () async {
      final normalized = _validate(draft);
      final secretRef = _newSecretRef();
      final apiKey = normalized.apiKey?.trim();
      final hasKey = apiKey != null && apiKey.isNotEmpty;
      if (hasKey) {
        final saved = await _secrets.write(secretRef, apiKey);
        final error = saved.when<AppException?>(
          success: (_) => null,
          failure: (error) => error,
        );
        if (error != null) throw error;
      }

      try {
        final config = await _db.transaction(() async {
          final count = await _count();
          final makeDefault = normalized.isDefault || count == 0;
          if (makeDefault) await _clearDefault();
          final now = DateTime.now().toUtc();
          final id = await _db
              .into(_db.llmProviderConfigs)
              .insert(
                db.LlmProviderConfigsCompanion.insert(
                  providerType: normalized.type.dbValue,
                  displayName: normalized.displayName,
                  baseUrl: normalized.baseUrl,
                  model: normalized.model,
                  maxTokens: Value(normalized.maxTokens),
                  secretRef: secretRef,
                  isDefault: Value(makeDefault),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          final row = await (_db.select(
            _db.llmProviderConfigs,
          )..where((t) => t.id.equals(id))).getSingle();
          return _config(row);
        });
        return config;
      } on Object {
        if (hasKey) await _secrets.delete(secretRef);
        rethrow;
      }
    });
  }

  @override
  Future<Result<LlmProviderConfig>> update(int id, LlmConfigDraft draft) {
    return RepositoryGuard.guard('LlmConfigRepository.update', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('LlmConfig: конфигурация $id не найдена');
      }
      final normalized = _validate(draft);
      final oldKeyResult = await _secrets.read(current.secretRef);
      final oldKey = oldKeyResult.unwrap();

      if (normalized.apiKey != null) {
        final key = normalized.apiKey!.trim();
        final saved = key.isEmpty
            ? await _secrets.delete(current.secretRef)
            : await _secrets.write(current.secretRef, key);
        final error = saved.when<AppException?>(
          success: (_) => null,
          failure: (error) => error,
        );
        if (error != null) throw error;
      }

      try {
        final config = await _db.transaction(() async {
          if (normalized.isDefault) await _clearDefault();
          final updated = await (_db.update(
            _db.llmProviderConfigs,
          )..where((t) => t.id.equals(id))).write(
            db.LlmProviderConfigsCompanion(
              providerType: Value(normalized.type.dbValue),
              displayName: Value(normalized.displayName),
              baseUrl: Value(normalized.baseUrl),
              model: Value(normalized.model),
              maxTokens: Value(normalized.maxTokens),
              isDefault: Value(normalized.isDefault),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
          if (updated == 0) {
            throw ValidationException('LlmConfig: конфигурация $id не найдена');
          }
          final row = await (_db.select(
            _db.llmProviderConfigs,
          )..where((t) => t.id.equals(id))).getSingle();
          return _config(row);
        });
        return config;
      } on Object {
        // Восстанавливаем старый ключ, если запись конфигурации не удалась.
        if (normalized.apiKey != null) {
          if (oldKey == null || oldKey.isEmpty) {
            await _secrets.delete(current.secretRef);
          } else {
            await _secrets.write(current.secretRef, oldKey);
          }
        }
        rethrow;
      }
    });
  }

  @override
  Future<Result<void>> delete(int id) {
    return RepositoryGuard.guard('LlmConfigRepository.delete', () async {
      final current = await _find(id);
      await (_db.delete(
        _db.llmProviderConfigs,
      )..where((t) => t.id.equals(id))).go();
      if (current != null) {
        final result = await _secrets.delete(current.secretRef);
        result.when(
          success: (_) {},
          failure: (error) => AppLogger.w(
            'LlmConfigRepository: не удалось удалить секрет конфигурации $id',
            error.message,
          ),
        );
      }
    });
  }

  @override
  Future<Result<void>> setDefault(int id) {
    return RepositoryGuard.guard('LlmConfigRepository.setDefault', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('LlmConfig: конфигурация $id не найдена');
      }
      await _db.transaction(() async {
        await _clearDefault();
        await (_db.update(
          _db.llmProviderConfigs,
        )..where((t) => t.id.equals(id))).write(
          db.LlmProviderConfigsCompanion(
            isDefault: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      });
    });
  }

  @override
  Future<Result<String?>> readApiKey(int id) {
    return RepositoryGuard.guard('LlmConfigRepository.readApiKey', () async {
      final current = await _find(id);
      if (current == null) {
        throw ValidationException('LlmConfig: конфигурация $id не найдена');
      }
      final value = await _secrets.read(current.secretRef);
      return value.unwrap();
    });
  }

  Future<db.LlmProviderConfig?> _find(int id) => (_db.select(
    _db.llmProviderConfigs,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> _count() async {
    final rows = await _db.select(_db.llmProviderConfigs).get();
    return rows.length;
  }

  Future<void> _clearDefault() async {
    await _db.update(_db.llmProviderConfigs).write(
      db.LlmProviderConfigsCompanion(isDefault: const Value(false)),
    );
  }

  String _newSecretRef() =>
      'llm.api_key.${DateTime.now().microsecondsSinceEpoch}'
      '.${_random.nextInt(1 << 32)}';

  static LlmProviderConfig _config(db.LlmProviderConfig row) =>
      LlmProviderConfig(
        id: row.id,
        type: LlmProviderType.fromDb(row.providerType),
        displayName: row.displayName,
        baseUrl: row.baseUrl,
        model: row.model,
        maxTokens: row.maxTokens,
        secretRef: row.secretRef,
        isDefault: row.isDefault,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  static LlmConfigDraft _validate(LlmConfigDraft draft) {
    final displayName = draft.displayName.trim();
    final model = draft.model.trim();
    final baseUrl = draft.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (displayName.isEmpty) {
      throw const ValidationException(
        'LlmConfig: название конфигурации не может быть пустым',
      );
    }
    if (model.isEmpty) {
      throw const ValidationException('LlmConfig: модель не может быть пустой');
    }
    if (draft.maxTokens < 1 || draft.maxTokens > 32768) {
      throw const ValidationException(
        'LlmConfig: лимит токенов должен быть от 1 до 32768',
      );
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const ValidationException(
        'LlmConfig: base URL должен начинаться с http:// или https://',
      );
    }
    return LlmConfigDraft(
      type: draft.type,
      displayName: displayName,
      baseUrl: baseUrl,
      model: model,
      maxTokens: draft.maxTokens,
      apiKey: draft.apiKey,
      isDefault: draft.isDefault,
    );
  }
}
