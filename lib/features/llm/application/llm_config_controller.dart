import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/llm_provider_config.dart';

/// Состояние списка LLM-конфигураций.
///
/// Контроллер намеренно возвращает bool: UI показывает локализованную
/// ошибку из ARB, а подробности (без ключей) остаются в логе.
class LlmConfigController extends AsyncNotifier<List<LlmProviderConfig>> {
  @override
  Future<List<LlmProviderConfig>> build() async {
    final repo = await ref.watch(llmConfigRepositoryProvider.future);
    return (await repo.list()).unwrap();
  }

  Future<bool> create(LlmConfigDraft draft) async {
    final repo = await ref.read(llmConfigRepositoryProvider.future);
    final result = await repo.create(draft);
    final ok = result.when<bool>(
      success: (config) {
        AppLogger.d('LlmConfigController: создана конфигурация ${config.id}');
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        return false;
      },
    );
    if (ok) await _reload();
    return ok;
  }

  Future<bool> updateConfig(int id, LlmConfigDraft draft) async {
    final repo = await ref.read(llmConfigRepositoryProvider.future);
    final result = await repo.update(id, draft);
    final ok = result.when<bool>(
      success: (config) {
        AppLogger.d('LlmConfigController: обновлена конфигурация ${config.id}');
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        return false;
      },
    );
    if (ok) await _reload();
    return ok;
  }

  Future<bool> delete(int id) async {
    final repo = await ref.read(llmConfigRepositoryProvider.future);
    final result = await repo.delete(id);
    final ok = result.when<bool>(
      success: (_) {
        AppLogger.d('LlmConfigController: удалена конфигурация $id');
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        return false;
      },
    );
    if (ok) await _reload();
    return ok;
  }

  Future<bool> setDefault(int id) async {
    final repo = await ref.read(llmConfigRepositoryProvider.future);
    final result = await repo.setDefault(id);
    final ok = result.when<bool>(
      success: (_) {
        AppLogger.d('LlmConfigController: выбран провайдер по умолчанию $id');
        return true;
      },
      failure: (error) {
        AppLogger.appError(error);
        return false;
      },
    );
    if (ok) await _reload();
    return ok;
  }

  Future<void> _reload() async {
    final repo = await ref.read(llmConfigRepositoryProvider.future);
    final result = await repo.list();
    result.when(
      success: (items) => state = AsyncData(items),
      failure: (error) {
        AppLogger.appError(error);
        state = AsyncError(error, StackTrace.current);
      },
    );
  }
}

final llmConfigControllerProvider =
    AsyncNotifierProvider<LlmConfigController, List<LlmProviderConfig>>(
      LlmConfigController.new,
    );

/// Первая конфигурация по умолчанию, иначе первая доступная.
LlmProviderConfig? defaultLlmConfig(List<LlmProviderConfig> configs) {
  if (configs.isEmpty) return null;
  for (final config in configs) {
    if (config.isDefault) return config;
  }
  return configs.first;
}

/// Провайдер по умолчанию для чата.
final defaultLlmConfigProvider = Provider<LlmProviderConfig?>((ref) {
  final configs = ref.watch(llmConfigControllerProvider).value;
  return configs == null ? null : defaultLlmConfig(configs);
});
