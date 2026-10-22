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
  }) {
    return RepositoryGuard.guard('SearchRepository.search', () async {
      final match = _toMatchQuery(query);
      if (match == null) return <SearchHit>[];
      final privacy = forLlm ? "AND is_private = '0'" : '';
      final rows = await _db
          .customSelect(
            '''
        SELECT entity_type, entity_id, title,
               snippet(search_index, 3, '<<', '>>', '…', 12) AS snippet,
               tags, is_private
        FROM search_index
        WHERE search_index MATCH ? $privacy
        ORDER BY bm25(search_index)
        LIMIT ?
        ''',
            variables: [Variable.withString(match), Variable.withInt(limit)],
          )
          .get();
      return [
        for (final row in rows)
          SearchHit(
            type: SearchEntityType.fromDb(row.read<String>('entity_type')),
            entityId: row.read<int>('entity_id'),
            title: row.read<String>('title'),
            snippet: row.read<String?>('snippet') ?? '',
            tags: (row.read<String?>('tags') ?? '')
                .split(' ')
                .where((t) => t.isNotEmpty)
                .toList(),
            isPrivateForLlm: row.read<String?>('is_private') == '1',
          ),
      ];
    });
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
