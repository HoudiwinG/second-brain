import 'package:drift/drift.dart';

import 'app_database_connection_stub.dart'
    if (dart.library.io) 'app_database_connection_io.dart'
    if (dart.library.js_interop) 'app_database_connection_web.dart'
    as impl;

/// Платформенное подключение к Drift: native SQLite или web WASM.
Future<DatabaseConnection> openAppDatabaseConnection() =>
    impl.openAppDatabaseConnection();
