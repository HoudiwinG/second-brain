import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

Future<DatabaseConnection> openAppDatabaseConnection() async {
  final dir = await getApplicationSupportDirectory();
  return DatabaseConnection(
    NativeDatabase.createInBackground(File('${dir.path}/second_brain.db')),
  );
}
