import 'package:drift/drift.dart';

import '../../core/result/result.dart';
import '../../features/search/domain/search_hit.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';

/// FTS5-поиск по локальному индексу.
class DriftSearchRepository implements SearchRepository {
  DriftSearchRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<SearchHit>>> search(
    String query, {
    bool forLlm = false,
    int limit = 50,
    Set<SearchEntityType>? types,
    DateTime? from,
    DateTime? to,
  }) {
    return RepositoryGuard.guard('SearchRepository.search', () async {
      final match = _toMatchQuery(query);
      if (match == null) return <SearchHit>[];
      final privacy = forLlm ? "AND is_private = '0'" : '';
      final typeFilter = types == null || types.isEmpty
          ? ''
          : 'AND entity_type IN (${List.filled(types.length, '?').join(',')})';
      // Если фильтруем по дате, дата вычисляется по исходной таблице уже после
      // FTS; поэтому не обрезаем выборку до фильтра.
      final sqlLimit = from != null || to != null ? -1 : limit;
      final variables = <Variable<Object>>[
        Variable.withString(match),
        for (final type in types ?? const <SearchEntityType>[])
          Variable.withString(type.name),
        Variable.withInt(sqlLimit),
      ];
      final rows = await _db.customSelect('''
        SELECT entity_type, entity_id, title,
               snippet(search_index, 3, '<<', '>>', '…', 12) AS snippet,
               tags, is_private
        FROM search_index
        WHERE search_index MATCH ? $privacy $typeFilter
        ORDER BY bm25(search_index)
        LIMIT ?
        ''', variables: variables).get();
      final hits = <SearchHit>[];
      for (final row in rows) {
        final hit = SearchHit(
          type: SearchEntityType.fromDb(row.read<String>('entity_type')),
          entityId: row.read<int>('entity_id'),
          title: row.read<String>('title'),
          snippet: row.read<String?>('snippet') ?? '',
          tags: (row.read<String?>('tags') ?? '')
              .split(' ')
              .where((t) => t.isNotEmpty)
              .toList(),
          isPrivateForLlm: row.read<String?>('is_private') == '1',
        );
        if (types != null && !types.contains(hit.type)) continue;
        DateTime? occurredAt;
        if (from != null || to != null) {
          occurredAt = await _occurredAt(hit.type, hit.entityId);
          if (from != null &&
              (occurredAt == null || occurredAt.isBefore(from))) {
            continue;
          }
          if (to != null && (occurredAt == null || !occurredAt.isBefore(to))) {
            continue;
          }
        }
        hits.add(
          SearchHit(
            type: hit.type,
            entityId: hit.entityId,
            title: hit.title,
            snippet: hit.snippet,
            tags: hit.tags,
            isPrivateForLlm: hit.isPrivateForLlm,
            occurredAt: occurredAt,
          ),
        );
      }
      return hits;
    });
  }

  Future<DateTime?> _occurredAt(SearchEntityType type, int id) async {
    switch (type) {
      case SearchEntityType.note:
        return (await (_db.select(
          _db.notes,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt;
      case SearchEntityType.task:
        return (await (_db.select(
          _db.tasks,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt;
      case SearchEntityType.idea:
        return (await (_db.select(
          _db.ideaEntries,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt;
      case SearchEntityType.finance:
        return (await (_db.select(
          _db.financeTransactions,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.date;
      case SearchEntityType.learning:
        return (await (_db.select(
          _db.learningTracks,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt;
      case SearchEntityType.chat:
        return (await (_db.select(
          _db.chatThreads,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt;
      case SearchEntityType.mail:
        return (await (_db.select(
          _db.mailMessages,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.receivedAt;
    }
  }

  @override
  Future<Result<void>> rebuild() {
    return RepositoryGuard.guard('SearchRepository.rebuild', () async {
      await rebuildSearchIndex(_db);
    });
  }

  /// Экранирует пользовательский ввод и превращает слова в prefix-запросы.
  String? _toMatchQuery(String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll('"', '""'))
        .map((t) => '"$t"*')
        .toList();
    if (terms.isEmpty) return null;
    return terms.join(' ');
  }
}
