/// Поддерживаемые типы LLM-провайдеров.
///
/// Значение [dbValue] хранится в БД и не должно меняться без миграции.
enum LlmProviderType {
  openai(
    dbValue: 'openai',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    suggestedModels: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
  ),
  openaiCompatible(
    dbValue: 'openai_compatible',
    defaultBaseUrl: 'http://localhost:11434/v1',
    defaultModel: 'llama3.1',
    suggestedModels: ['llama3.1', 'qwen2.5', 'mistral'],
  ),
  anthropic(
    dbValue: 'anthropic',
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    defaultModel: 'claude-3-5-sonnet-latest',
    suggestedModels: [
      'claude-3-5-sonnet-latest',
      'claude-3-5-haiku-latest',
    ],
  ),
  google(
    dbValue: 'google',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    defaultModel: 'gemini-2.0-flash',
    suggestedModels: ['gemini-2.0-flash', 'gemini-1.5-pro'],
  );

  const LlmProviderType({
    required this.dbValue,
    required this.defaultBaseUrl,
    required this.defaultModel,
    required this.suggestedModels,
  });

  /// Стабильное значение для БД.
  final String dbValue;

  /// Базовый URL по умолчанию (без завершающего слэша).
  final String defaultBaseUrl;

  /// Модель по умолчанию для новой конфигурации.
  final String defaultModel;

  /// Подсказки в UI; пользователь может ввести собственную модель.
  final List<String> suggestedModels;

  /// true — провайдер умеет строить эмбеддинги.
  bool get supportsEmbeddings => this != LlmProviderType.anthropic;

  /// Разбор значения из БД. Неизвестное значение трактуется как
  /// OpenAI-compatible, чтобы старые/ручные конфиги не роняли приложение.
  static LlmProviderType fromDb(String raw) => LlmProviderType.values
      .firstWhere((type) => type.dbValue == raw, orElse: () => openaiCompatible);
}
