import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/result/result.dart';
import '../db/app_database.dart' as db;
import 'repository_guard.dart';

/// Итог вызова инструмента для аудита.
enum ToolAuditStatus {
  ok('ok'),
  error('error'),
  unknownTool('unknown_tool'),
  invalidArgs('invalid_args');

  const ToolAuditStatus(this.dbValue);

  final String dbValue;
}

/// Запись аудита. Значения аргументов сюда не передаются: только имена.
class ToolAuditDraft {
  const ToolAuditDraft({
    required this.toolName,
    required this.status,
    this.argumentNames = const [],
    this.entityId,
    required this.createdAt,
  });

  final String toolName;
  final ToolAuditStatus status;
  final List<String> argumentNames;
  final int? entityId;
  final DateTime createdAt;
}

/// Журнал вызовов инструментов ассистента.
abstract interface class ToolAuditRepository {
  Future<Result<void>> record(ToolAuditDraft draft);

  Future<Result<List<ToolAuditDraft>>> listRecent({int limit = 50});
}

/// Drift-реализация [ToolAuditRepository].
class DriftToolAuditRepository implements ToolAuditRepository {
  DriftToolAuditRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<void>> record(ToolAuditDraft draft) {
    return RepositoryGuard.guard('ToolAuditRepository.record', () async {
      await _db
          .into(_db.toolAuditEntries)
          .insert(
            db.ToolAuditEntriesCompanion.insert(
              toolName: draft.toolName,
              status: draft.status.dbValue,
              argumentNames: Value(_encodeNames(draft.argumentNames)),
              entityId: Value(draft.entityId),
              createdAt: draft.createdAt,
            ),
          );
    });
  }

  @override
  Future<Result<List<ToolAuditDraft>>> listRecent({int limit = 50}) {
    return RepositoryGuard.guard('ToolAuditRepository.listRecent', () async {
      final query = _db.select(_db.toolAuditEntries)
        ..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.id),
        ])
        ..limit(limit);
      final rows = await query.get();
      return [
        for (final row in rows)
          ToolAuditDraft(
            toolName: row.toolName,
            status: ToolAuditStatus.values.firstWhere(
              (value) => value.dbValue == row.status,
              orElse: () => ToolAuditStatus.error,
            ),
            argumentNames: _decodeNames(row.argumentNames),
            entityId: row.entityId,
            createdAt: row.createdAt,
          ),
      ];
    });
  }

  /// JSON-массив не ломается на именах с запятыми, в отличие от `join(',')`.
  static String _encodeNames(List<String> names) => jsonEncode(names);

  /// До исправления S04-003 имена хранились через запятую. Читаем оба
  /// формата, чтобы не терять уже записанный аудит.
  static List<String> _decodeNames(String raw) {
    if (raw.isEmpty) return const [];
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return [
            for (final item in decoded)
              if (item is String) item,
          ];
        }
      } on FormatException {
        // Повреждённое значение читаем как старый формат.
      }
    }
    return raw.split(',');
  }
}
