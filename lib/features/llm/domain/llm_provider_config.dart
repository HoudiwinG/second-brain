import 'llm_provider_type.dart';

/// Сохранённая конфигурация провайдера.
///
/// API-ключ хранится отдельно в [SecretStore] по ссылке [secretRef].
final class LlmProviderConfig {
  const LlmProviderConfig({
    required this.id,
    required this.type,
    required this.displayName,
    required this.baseUrl,
    required this.model,
    required this.maxTokens,
    required this.secretRef,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.embeddingModel,
    this.hasApiKey = false,
  });

  final int id;
  final LlmProviderType type;
  final String displayName;
  final String baseUrl;
  final String model;
  final int maxTokens;
  final String secretRef;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Модель embeddings. null — использовать тип/чат-модель по умолчанию.
  final String? embeddingModel;

  /// true, если в secure storage есть непустой ключ. Сам ключ не хранится.
  final bool hasApiKey;
}

/// Данные создания/редактирования конфигурации.
final class LlmConfigDraft {
  const LlmConfigDraft({
    required this.type,
    required this.displayName,
    required this.baseUrl,
    required this.model,
    this.maxTokens = 1024,
    this.embeddingModel,
    this.apiKey,
    this.isDefault = false,
  });

  final LlmProviderType type;
  final String displayName;
  final String baseUrl;
  final String model;
  final int maxTokens;

  /// Модель embeddings; пустое значение — умолчание провайдера.
  final String? embeddingModel;

  /// null при обновлении означает «не менять ключ»; пустая строка — удалить.
  final String? apiKey;

  final bool isDefault;

  LlmConfigDraft copyWith({
    LlmProviderType? type,
    String? displayName,
    String? baseUrl,
    String? model,
    int? maxTokens,
    Object? embeddingModel = _unset,
    Object? apiKey = _unset,
    bool? isDefault,
  }) => LlmConfigDraft(
    type: type ?? this.type,
    displayName: displayName ?? this.displayName,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    maxTokens: maxTokens ?? this.maxTokens,
    embeddingModel: identical(embeddingModel, _unset)
        ? this.embeddingModel
        : embeddingModel as String?,
    apiKey: identical(apiKey, _unset) ? this.apiKey : apiKey as String?,
    isDefault: isDefault ?? this.isDefault,
  );
}

const Object _unset = Object();
