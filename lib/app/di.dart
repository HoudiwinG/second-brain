import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/secrets/secret_store.dart';
import '../core/secrets/secure_secret_store.dart';
import '../data/db/app_database.dart';
import '../data/repositories/settings_repository.dart';
import 'router.dart';

/// DI-контейнеры Riverpod (этап 0).

/// База данных приложения. Лениво открывается при первом обращении;
/// закрывается при разрушении провайдера.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// Репозиторий настроек поверх готовой БД.
final settingsRepositoryProvider = FutureProvider<SettingsRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return SettingsRepository(db);
});

/// Хранилище секретов: secure storage (DPAPI/Keychain/Keystore).
final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

/// Роутер приложения.
final routerProvider = Provider<RouterController>((ref) => RouterController());
