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

  /// Есть ли у конфигурации сохранённый ключ (проверяется репозиторием).
  bool get isLocal =>
      type == LlmProviderType.openaiCompatible &&
      (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1'));
}

/// Данные создания/редактирования конфигурации.
final class LlmConfigDraft {
  const LlmConfigDraft({
    required this.type,
    required this.displayName,
    required this.baseUrl,
    required this.model,
    this.maxTokens = 1024,
    this.apiKey,
    this.isDefault = false,
  });

  final LlmProviderType type;
  final String displayName;
  final String baseUrl;
  final String model;
  final int maxTokens;

  /// null при обновлении означает «не менять ключ»; пустая строка — удалить.
  final String? apiKey;

  final bool isDefault;

  LlmConfigDraft copyWith({
    LlmProviderType? type,
    String? displayName,
    String? baseUrl,
    String? model,
    int? maxTokens,
    Object? apiKey = _unset,
    bool? isDefault,
  }) => LlmConfigDraft(
    type: type ?? this.type,
    displayName: displayName ?? this.displayName,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    maxTokens: maxTokens ?? this.maxTokens,
    apiKey: identical(apiKey, _unset) ? this.apiKey : apiKey as String?,
    isDefault: isDefault ?? this.isDefault,
  );
}

const Object _unset = Object();
