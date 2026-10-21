import 'app_flag.dart';

/// Реестр фича-флагов для управления монетизацией и экспериментами.
///
/// Значения по умолчанию — «выключено» для всех коммерческих функций.
/// Сохранение/чтение флагов из Settings-таблицы появятся на этапе 1+.
abstract final class FeatureFlags {
  static const Map<String, AppFlag> _defaults = {
    'premium.enabled': AppFlag(
      key: 'premium.enabled',
      description: 'Флаг монетизации: премиум-подписка (заготовка)',
      enabled: false,
    ),
    'cloud.sync.enabled': AppFlag(
      key: 'cloud.sync.enabled',
      description: 'Облачная синхронизация (пока только интерфейс SyncService)',
      enabled: false,
    ),
    'experimental.emailOauth': AppFlag(
      key: 'experimental.emailOauth',
      description: 'OAuth для почтовых ящиков (этап 6)',
      enabled: false,
    ),
    'experimental.llmChat': AppFlag(
      key: 'experimental.llmChat',
      description: 'AI-чат с LLM-провайдером (этап 3)',
      enabled: true,
    ),
  };

  static Map<String, AppFlag> get defaults => Map.unmodifiable(_defaults);

  /// Возвращает текущее значение флага (сейчас — только дефолты).
  static bool isEnabled(String key) => _defaults[key]?.enabled ?? false;
}
