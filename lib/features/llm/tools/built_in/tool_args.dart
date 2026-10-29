import '../../../../core/error/app_exception.dart';

/// Приводит любую ошибку инструмента к [AppException] без текста исходной
/// ошибки: он может содержать значения аргументов.
AppException toToolException(Object error) => switch (error) {
  AppException() => error,
  _ => const DataException('Инструмент завершился ошибкой'),
};

/// Разбор аргументов инструментов. Сообщения об ошибках называют только
/// имя аргумента: значения пользователя не попадают ни в лог, ни в аудит.
abstract final class ToolArgs {
  static String requireString(Map<String, Object?> args, String key) {
    final value = optionalString(args, key)?.trim() ?? '';
    if (value.isEmpty) {
      throw ValidationException('Аргумент "$key" обязателен');
    }
    return value;
  }

  static String? optionalString(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! String) {
      throw ValidationException('Аргумент "$key" должен быть строкой');
    }
    return value;
  }

  static int requireInt(Map<String, Object?> args, String key) {
    final value = optionalInt(args, key);
    if (value == null) {
      throw ValidationException('Аргумент "$key" обязателен');
    }
    return value;
  }

  static int? optionalInt(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    throw ValidationException('Аргумент "$key" должен быть целым числом');
  }

  static bool optionalBool(
    Map<String, Object?> args,
    String key, {
    bool fallback = false,
  }) {
    final value = args[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw ValidationException('Аргумент "$key" должен быть true или false');
  }

  static DateTime? optionalDateTime(Map<String, Object?> args, String key) {
    final raw = optionalString(args, key);
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) {
      throw ValidationException('Аргумент "$key" должен быть датой ISO 8601');
    }
    return parsed;
  }

  static List<String> optionalStringList(
    Map<String, Object?> args,
    String key,
  ) {
    final value = args[key];
    if (value == null) return const [];
    if (value is! List || value.any((item) => item is! String)) {
      throw ValidationException('Аргумент "$key" должен быть списком строк');
    }
    return [for (final item in value) (item as String).trim()]
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static T? optionalEnum<T extends Enum>(
    Map<String, Object?> args,
    String key,
    List<T> values,
  ) {
    final raw = optionalString(args, key);
    if (raw == null) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw ValidationException('Аргумент "$key" имеет недопустимое значение');
  }
}
