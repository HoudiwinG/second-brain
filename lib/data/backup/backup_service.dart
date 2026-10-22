import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, OrderingTerm, Value;

import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../db/app_database.dart' as db;
import '../repositories/repository_guard.dart';
import '../repositories/tag_utils.dart';
import '../search/search_index.dart';

/// Экспорт/импорт данных stage-01.
///
/// JSON — полный бэкап всех сущностей (категории, теги, заметки, задачи,
/// идеи, финансы). CSV — финансы (RFC 4180), совместим с таблицами.
/// Импорт JSON заменяет локальные данные целиком; импорт CSV добавляет
/// операции. FTS-индекс перестраивается после импорта.
class BackupService {
  BackupService(this._db);

  static const String format = 'second-brain.backup';
  static const int version = 1;

  final db.AppDatabase _db;

  Future<Result<void>> exportJson(File file, {bool includeDeleted = false}) {
    return RepositoryGuard.guard('BackupService.exportJson', () async {
      final map = await _buildBackup(includeDeleted: includeDeleted);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(map),
        flush: true,
      );
      AppLogger.d('BackupService: JSON экспортирован (${map.length} разделов)');
    });
  }

  Future<Result<void>> importJson(File file) {
    return RepositoryGuard.guard('BackupService.importJson', () async {
      final raw = await file.readAsString();
      final decoded = _decodeObject(raw, 'JSON');
      _validateHeader(decoded);
      await _db.transaction(() async {
        await _clearAll();
        await _importJsonData(decoded);
        await rebuildSearchIndex(_db);
      });
      AppLogger.d('BackupService: JSON импортирован');
    });
  }

  Future<Result<void>> exportFinanceCsv(
    File file, {
    bool includeDeleted = false,
  }) {
    return RepositoryGuard.guard('BackupService.exportFinanceCsv', () async {
      final query = _db.select(_db.financeTransactions);
      if (!includeDeleted) {
        query.where((t) => t.deletedAt.isNull());
      }
      query.orderBy([(t) => OrderingTerm.asc(t.date)]);
      final rows = await query.get();
      final buffer = StringBuffer()
        ..writeln(
          'id,amount,currency,type,category,account,date,note,'
          'is_private,created_at,updated_at,deleted_at',
        );
      for (final row in rows) {
        buffer.writeln(
          [
            row.id.toString(),
            row.amount.toString(),
            row.currency,
            row.type,
            row.category ?? '',
            row.account ?? '',
            row.date.toUtc().toIso8601String(),
            row.note ?? '',
            row.isPrivateForLlm ? '1' : '0',
            row.createdAt.toUtc().toIso8601String(),
            row.updatedAt.toUtc().toIso8601String(),
            row.deletedAt?.toUtc().toIso8601String() ?? '',
          ].map(_csvField).join(','),
        );
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(buffer.toString(), flush: true);
      AppLogger.d('BackupService: CSV экспортирован ($rows)');
    });
  }

  Future<Result<void>> importFinanceCsv(File file) {
    return RepositoryGuard.guard('BackupService.importFinanceCsv', () async {
      final raw = await file.readAsString();
      final rows = _parseCsv(raw);
      if (rows.isEmpty) {
        throw const ValidationException('BackupService: CSV пуст');
      }
      final header = rows.first
          .map((h) => h.replaceFirst('\uFEFF', '').trim().toLowerCase())
          .toList();
      int index(String name) {
        final i = header.indexOf(name);
        if (i < 0) {
          throw ValidationException('BackupService: в CSV нет колонки "$name"');
        }
        return i;
      }

      final amountIndex = index('amount');
      final typeIndex = index('type');
      final dateIndex = index('date');
      final currencyIndex = header.indexOf('currency');
      final categoryIndex = header.indexOf('category');
      final accountIndex = header.indexOf('account');
      final noteIndex = header.indexOf('note');
      final privacyIndex = header.indexOf('is_private');
      final createdIndex = header.indexOf('created_at');
      final updatedIndex = header.indexOf('updated_at');
      final deletedIndex = header.indexOf('deleted_at');

      String? cell(List<String> row, int i) =>
          i >= 0 && i < row.length ? row[i].trim() : null;

      await _db.transaction(() async {
        for (final row in rows.skip(1)) {
          if (row.every((c) => c.trim().isEmpty)) continue;
          final amount = double.tryParse(cell(row, amountIndex) ?? '');
          if (amount == null || amount <= 0) {
            throw const ValidationException(
              'BackupService: некорректная сумма в CSV',
            );
          }
          final type = FinanceTransactionTypeParser.parse(cell(row, typeIndex));
          final date =
              _parseDate(cell(row, dateIndex)) ?? DateTime.now().toUtc();
          final now = DateTime.now().toUtc();
          final id = await _db
              .into(_db.financeTransactions)
              .insert(
                db.FinanceTransactionsCompanion.insert(
                  amount: amount,
                  currency: Value(
                    (cell(row, currencyIndex) ?? '').isEmpty
                        ? 'RUB'
                        : cell(row, currencyIndex)!.toUpperCase(),
                  ),
                  type: type,
                  category: Value(_emptyToNull(cell(row, categoryIndex))),
                  account: Value(_emptyToNull(cell(row, accountIndex))),
                  date: date,
                  note: Value(_emptyToNull(cell(row, noteIndex))),
                  isPrivateForLlm: Value(
                    (cell(row, privacyIndex) ?? '0') == '1' ||
                        (cell(row, privacyIndex) ?? '').toLowerCase() == 'true',
                  ),
                  createdAt: _parseDate(cell(row, createdIndex)) ?? now,
                  updatedAt: _parseDate(cell(row, updatedIndex)) ?? now,
                  deletedAt: Value(_parseDate(cell(row, deletedIndex))),
                ),
              );
          await indexFinance(_db, id);
        }
      });
      AppLogger.d('BackupService: CSV импортирован');
    });
  }

  Future<Map<String, Object?>> _buildBackup({
    required bool includeDeleted,
  }) async {
    final categories = await _db.select(_db.categories).get();
    final tags = await _db.select(_db.tags).get();
    final notes = _visible(
      await _db.select(_db.notes).get(),
      includeDeleted,
      (row) => row.deletedAt,
    );
    final tasks = _visible(
      await _db.select(_db.tasks).get(),
      includeDeleted,
      (row) => row.deletedAt,
    );
    final ideas = _visible(
      await _db.select(_db.ideaEntries).get(),
      includeDeleted,
      (row) => row.deletedAt,
    );
    final finance = _visible(
      await _db.select(_db.financeTransactions).get(),
      includeDeleted,
      (row) => row.deletedAt,
    );

    return {
      'format': format,
      'version': version,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'categories': [
        for (final row in categories)
          {
            'id': row.id,
            'name': row.name,
            'parent_id': row.parentId,
            'created_at': _iso(row.createdAt),
            'updated_at': _iso(row.updatedAt),
          },
      ],
      'tags': [
        for (final row in tags)
          {'id': row.id, 'name': row.name, 'created_at': _iso(row.createdAt)},
      ],
      'notes': [
        for (final row in notes)
          {
            'id': row.id,
            'title': row.title,
            'body': row.body,
            'category_id': row.categoryId,
            'tags': await tagsForNote(_db, row.id),
            'is_private_for_llm': row.isPrivateForLlm,
            'created_at': _iso(row.createdAt),
            'updated_at': _iso(row.updatedAt),
            'deleted_at': _iso(row.deletedAt),
          },
      ],
      'tasks': [
        for (final row in tasks)
          {
            'id': row.id,
            'title': row.title,
            'description': row.description,
            'priority': row.priority,
            'due_at': _iso(row.dueAt),
            'remind_at': _iso(row.remindAt),
            'status': row.status,
            'tags': await tagsForTask(_db, row.id),
            'linked_note_id': row.linkedNoteId,
            'is_private_for_llm': row.isPrivateForLlm,
            'recurrence': row.recurrence,
            'created_at': _iso(row.createdAt),
            'updated_at': _iso(row.updatedAt),
            'deleted_at': _iso(row.deletedAt),
          },
      ],
      'ideas': [
        for (final row in ideas)
          {
            'id': row.id,
            'text': row.content,
            'source': row.source,
            'mood': row.mood,
            'tags': await tagsForIdea(_db, row.id),
            'is_private_for_llm': row.isPrivateForLlm,
            'created_at': _iso(row.createdAt),
            'updated_at': _iso(row.updatedAt),
            'deleted_at': _iso(row.deletedAt),
          },
      ],
      'finance': [
        for (final row in finance)
          {
            'id': row.id,
            'amount': row.amount,
            'currency': row.currency,
            'type': row.type,
            'category': row.category,
            'account': row.account,
            'date': _iso(row.date),
            'note': row.note,
            'is_private_for_llm': row.isPrivateForLlm,
            'created_at': _iso(row.createdAt),
            'updated_at': _iso(row.updatedAt),
            'deleted_at': _iso(row.deletedAt),
          },
      ],
    };
  }

  List<T> _visible<T>(
    List<T> rows,
    bool includeDeleted,
    DateTime? Function(T row) deletedAt,
  ) => includeDeleted ? rows : rows.where((r) => deletedAt(r) == null).toList();

  Map<String, dynamic> _decodeObject(String raw, String label) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const ValidationException('BackupService: ожидается JSON-объект');
      }
      return decoded;
    } on FormatException catch (e, s) {
      throw ValidationException(
        'BackupService: некорректный $label',
        cause: e,
        stackTrace: s,
      );
    }
  }

  void _validateHeader(Map<String, dynamic> data) {
    if (data['format'] != format) {
      throw const ValidationException('BackupService: неизвестный формат');
    }
    final fileVersion = data['version'];
    if (fileVersion is! int || fileVersion > version) {
      throw ValidationException(
        'BackupService: версия бэкапа $fileVersion не поддерживается',
      );
    }
    for (final key in [
      'categories',
      'tags',
      'notes',
      'tasks',
      'ideas',
      'finance',
    ]) {
      if (data[key] is! List) {
        throw ValidationException('BackupService: нет массива "$key"');
      }
    }
  }

  Future<void> _clearAll() async {
    await _db.customStatement('DELETE FROM search_index');
    await _db.delete(_db.noteTags).go();
    await _db.delete(_db.taskTags).go();
    await _db.delete(_db.ideaTags).go();
    await _db.delete(_db.tasks).go();
    await _db.delete(_db.ideaEntries).go();
    await _db.delete(_db.financeTransactions).go();
    await _db.delete(_db.notes).go();
    await _db.delete(_db.tags).go();
    await _db.delete(_db.categories).go();
  }

  Future<void> _importJsonData(Map<String, dynamic> data) async {
    final categoryIds = <int>{};
    final pending = [
      for (final item in data['categories'] as List) _map(item, 'category'),
    ];
    while (pending.isNotEmpty) {
      final progressed = <Map<String, dynamic>>[];
      for (final item in pending) {
        final parentId = _intOrNull(item['parent_id']);
        if (parentId != null && !categoryIds.contains(parentId)) {
          progressed.add(item);
          continue;
        }
        final id = _requiredInt(item, 'id');
        final now = DateTime.now().toUtc();
        await _db
            .into(_db.categories)
            .insert(
              db.CategoriesCompanion.insert(
                id: Value(id),
                name: _requiredString(item, 'name'),
                parentId: Value(parentId),
                createdAt: _dateOrNow(item['created_at'], now),
                updatedAt: _dateOrNow(item['updated_at'], now),
              ),
            );
        categoryIds.add(id);
      }
      if (progressed.length == pending.length) {
        throw const ValidationException(
          'BackupService: циклическая или битая иерархия категорий',
        );
      }
      pending
        ..clear()
        ..addAll(progressed);
    }

    final tagIds = <String, int>{};
    for (final item in (data['tags'] as List)) {
      final tag = _map(item, 'tag');
      final name = _requiredString(tag, 'name').trim();
      final id = _requiredInt(tag, 'id');
      await _db
          .into(_db.tags)
          .insert(
            db.TagsCompanion.insert(
              id: Value(id),
              name: name,
              createdAt: _dateOrNow(tag['created_at'], DateTime.now().toUtc()),
            ),
          );
      tagIds[name.toLowerCase()] = id;
    }

    Future<int> tagId(String name) async {
      final normalized = name.trim();
      final existing = tagIds[normalized.toLowerCase()];
      if (existing != null) return existing;
      final id = await _db
          .into(_db.tags)
          .insert(
            db.TagsCompanion.insert(
              name: normalized,
              createdAt: DateTime.now().toUtc(),
            ),
          );
      tagIds[normalized.toLowerCase()] = id;
      return id;
    }

    final noteIds = <int>{};
    for (final item in (data['notes'] as List)) {
      final note = _map(item, 'note');
      final id = _requiredInt(note, 'id');
      final categoryId = _intOrNull(note['category_id']);
      await _db
          .into(_db.notes)
          .insert(
            db.NotesCompanion.insert(
              id: Value(id),
              title: _requiredString(note, 'title'),
              body: Value(_string(note['body'])),
              categoryId: Value(
                categoryId != null && categoryIds.contains(categoryId)
                    ? categoryId
                    : null,
              ),
              isPrivateForLlm: Value(_bool(note['is_private_for_llm'])),
              createdAt: _requiredDate(note, 'created_at'),
              updatedAt: _requiredDate(note, 'updated_at'),
              deletedAt: Value(_dateOrNull(note['deleted_at'])),
            ),
          );
      noteIds.add(id);
      for (final name in _stringList(note['tags'])) {
        await _db
            .into(_db.noteTags)
            .insert(
              db.NoteTagsCompanion.insert(noteId: id, tagId: await tagId(name)),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }

    for (final item in (data['tasks'] as List)) {
      final task = _map(item, 'task');
      final id = _requiredInt(task, 'id');
      final linkedNoteId = _intOrNull(task['linked_note_id']);
      await _db
          .into(_db.tasks)
          .insert(
            db.TasksCompanion.insert(
              id: Value(id),
              title: _requiredString(task, 'title'),
              description: Value(_string(task['description'])),
              priority: Value(_stringOr(task['priority'], 'normal')),
              dueAt: Value(_dateOrNull(task['due_at'])),
              remindAt: Value(_dateOrNull(task['remind_at'])),
              status: Value(_stringOr(task['status'], 'todo')),
              linkedNoteId: Value(
                linkedNoteId != null && noteIds.contains(linkedNoteId)
                    ? linkedNoteId
                    : null,
              ),
              isPrivateForLlm: Value(_bool(task['is_private_for_llm'])),
              recurrence: Value(_emptyToNull(task['recurrence']?.toString())),
              createdAt: _requiredDate(task, 'created_at'),
              updatedAt: _requiredDate(task, 'updated_at'),
              deletedAt: Value(_dateOrNull(task['deleted_at'])),
            ),
          );
      for (final name in _stringList(task['tags'])) {
        await _db
            .into(_db.taskTags)
            .insert(
              db.TaskTagsCompanion.insert(taskId: id, tagId: await tagId(name)),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }

    for (final item in (data['ideas'] as List)) {
      final idea = _map(item, 'idea');
      final id = _requiredInt(idea, 'id');
      await _db
          .into(_db.ideaEntries)
          .insert(
            db.IdeaEntriesCompanion.insert(
              id: Value(id),
              content: _requiredString(idea, 'text'),
              source: Value(_emptyToNull(idea['source']?.toString())),
              mood: Value(_emptyToNull(idea['mood']?.toString())),
              isPrivateForLlm: Value(_bool(idea['is_private_for_llm'])),
              createdAt: _requiredDate(idea, 'created_at'),
              updatedAt: _requiredDate(idea, 'updated_at'),
              deletedAt: Value(_dateOrNull(idea['deleted_at'])),
            ),
          );
      for (final name in _stringList(idea['tags'])) {
        await _db
            .into(_db.ideaTags)
            .insert(
              db.IdeaTagsCompanion.insert(ideaId: id, tagId: await tagId(name)),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }

    for (final item in (data['finance'] as List)) {
      final transaction = _map(item, 'finance');
      final id = _requiredInt(transaction, 'id');
      await _db
          .into(_db.financeTransactions)
          .insert(
            db.FinanceTransactionsCompanion.insert(
              id: Value(id),
              amount: _requiredDouble(transaction, 'amount'),
              currency: Value(_stringOr(transaction['currency'], 'RUB')),
              type: _stringOr(transaction['type'], 'expense'),
              category: Value(
                _emptyToNull(transaction['category']?.toString()),
              ),
              account: Value(_emptyToNull(transaction['account']?.toString())),
              date: _requiredDate(transaction, 'date'),
              note: Value(_emptyToNull(transaction['note']?.toString())),
              isPrivateForLlm: Value(_bool(transaction['is_private_for_llm'])),
              createdAt: _requiredDate(transaction, 'created_at'),
              updatedAt: _requiredDate(transaction, 'updated_at'),
              deletedAt: Value(_dateOrNull(transaction['deleted_at'])),
            ),
          );
    }
  }

  Map<String, dynamic> _map(Object? value, String label) {
    if (value is Map<String, dynamic>) return value;
    throw ValidationException('BackupService: некорректный объект "$label"');
  }

  int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw ValidationException('BackupService: поле "$key" должно быть числом');
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ValidationException('BackupService: поле "$key" обязательно');
  }

  String _string(Object? value) => value is String ? value : '';

  String _stringOr(Object? value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _bool(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  double _requiredDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw ValidationException('BackupService: поле "$key" должно быть числом');
  }

  DateTime _requiredDate(Map<String, dynamic> map, String key) {
    final value = _dateOrNull(map[key]);
    if (value == null) {
      throw ValidationException(
        'BackupService: поле "$key" — некорректная дата',
      );
    }
    return value;
  }

  DateTime? _dateOrNull(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  DateTime _dateOrNow(Object? value, DateTime fallback) =>
      _dateOrNull(value) ?? fallback;

  DateTime? _parseDate(String? value) =>
      value == null || value.isEmpty ? null : DateTime.tryParse(value)?.toUtc();

  String? _iso(DateTime? value) => value?.toUtc().toIso8601String();

  String _csvField(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < raw.length && raw[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        row.add(field.toString());
        field.clear();
      } else if (char == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else if (char != '\r') {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}

/// Парсер типа операции для CSV (без зависимости от domain-слоя).
abstract final class FinanceTransactionTypeParser {
  static String parse(String? value) =>
      value?.trim().toLowerCase() == 'income' ? 'income' : 'expense';
}
