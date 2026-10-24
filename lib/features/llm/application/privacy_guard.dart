import '../../../core/logging/app_logger.dart';

/// Сущность приложения, которую потенциально можно отправить в LLM.
final class LlmContextItem {
  const LlmContextItem({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.isPrivateForLlm,
  });

  final String entityType;
  final int entityId;
  final String title;
  final String body;

  /// true — сущность запрещено отправлять во внешнюю LLM.
  final bool isPrivateForLlm;
}

/// Результат фильтрации контекста.
final class PrivacyFilterResult {
  const PrivacyFilterResult({
    required this.allowed,
    required this.filteredCount,
    required this.filteredTypes,
  });

  final List<LlmContextItem> allowed;
  final int filteredCount;
  final Set<String> filteredTypes;

  bool get hasFiltered => filteredCount > 0;
}

/// Единая точка фильтрации приватных сущностей перед LLM-запросом.
///
/// Логируется только количество и типы отфильтрованных сущностей — никогда
/// их заголовки или содержимое. Это требование PROMPT.md по privacy guard.
abstract final class PrivacyGuard {
  static PrivacyFilterResult filter(Iterable<LlmContextItem> items) {
    final allowed = <LlmContextItem>[];
    final filteredTypes = <String>{};
    var filtered = 0;
    for (final item in items) {
      if (item.isPrivateForLlm) {
        filtered++;
        filteredTypes.add(item.entityType);
      } else {
        allowed.add(item);
      }
    }
    if (filtered > 0) {
      AppLogger.w(
        'PrivacyGuard: отфильтровано $filtered сущностей '
        '(типы: ${filteredTypes.join(', ')})',
      );
    }
    return PrivacyFilterResult(
      allowed: allowed,
      filteredCount: filtered,
      filteredTypes: filteredTypes,
    );
  }
}
