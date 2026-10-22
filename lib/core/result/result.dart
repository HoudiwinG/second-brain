import '../error/app_exception.dart';

/// Базовый контейнер результата операций без исключений.
///
/// Используйте [Result.success] для успешного значения и [Result.failure]
/// для ошибки. Метод [when] позволяет обработать оба исхода исчерпывающе.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(AppException error) = Failure<T>;

  /// Разворачивает результат в значение или пробрасывает [AppException].
  T unwrap() => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>(:final error) => throw error,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(AppException error) failure,
  }) => switch (this) {
    Success<T>(:final value) => success(value),
    Failure<T>(:final error) => failure(error),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  String toString() => 'Result.success($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppException error;

  @override
  String toString() => 'Result.failure($error)';
}
