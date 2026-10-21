import 'package:second_brain/data/db/app_database.dart';

/// In-memory вариант [AppDatabase] для тестов.
///
/// Базы живут в памяти и закрываются в tearDown вызывающего теста
/// (через addTearDown).
abstract final class InMemoryDbFactory {
  /// Создаёт полностью in-memory базу со свежей схемой.
  static AppDatabase open() => AppDatabase.inMemory();
}
