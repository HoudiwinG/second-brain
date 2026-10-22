import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';

/// Единая обработка ошибок репозиториев: наружу отдаём [Result], а не throw.
abstract final class RepositoryGuard {
  static Future<Result<T>> guard<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return Result.success(await action());
    } on AppException catch (e) {
      return Result.failure(e);
    } on Exception catch (e, s) {
      return Result.failure(DataException(operation, cause: e, stackTrace: s));
    }
  }
}
