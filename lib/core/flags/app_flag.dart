/// Описание одного фича-флага.
final class AppFlag {
  const AppFlag({
    required this.key,
    required this.description,
    this.enabled = false,
  });

  /// Технический флаг-идентификатор, например `premium.enabled`.
  final String key;

  /// Человеческое описание (для настроек/логирования).
  final String description;

  /// Включён ли флаг.
  final bool enabled;
}
