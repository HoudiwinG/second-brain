import '../result/result.dart';
import 'secret_store.dart';

/// In-memory реализация [SecretStore] для юнит/виджет-тестов.
final class InMemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  /// Прямой доступ к значениям — только для тестов/отладки.
  Map<String, String> get debugValues => Map.unmodifiable(_values);

  @override
  Future<Result<String?>> read(String key) async => Result.success(_values[key]);

  @override
  Future<Result<void>> write(String key, String value) async {
    _values[key] = value;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    _values.remove(key);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> clear() async {
    _values.clear();
    return const Result.success(null);
  }
}
