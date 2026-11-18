import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import '../../core/logging/app_logger.dart';

/// Web-хранилище Drift (WASM + IndexedDB/OPFS).
///
/// Файлы `sqlite3.wasm` и `drift_worker.js` лежат в `web/`.
Future<DatabaseConnection> openAppDatabaseConnection() async {
  final result = await WasmDatabase.open(
    databaseName: 'second_brain',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  AppLogger.i(
    'AppDatabase web: ${result.chosenImplementation.name}, '
    'missing=${result.missingFeatures.map((f) => f.name).join(',')}',
  );
  return result.resolvedExecutor;
}
