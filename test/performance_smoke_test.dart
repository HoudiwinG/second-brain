import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/db/app_database.dart';
import 'package:second_brain/data/repositories/search_repository.dart';
import 'package:second_brain/data/search/search_index.dart';

import 'helpers/in_memory_db.dart';

void main() {
  test('performance smoke: rebuild и FTS на 1000 заметках', () async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final now = DateTime.utc(2026, 1, 1);
    final insert = Stopwatch()..start();
    await db.batch((batch) {
      batch.insertAll(db.notes, [
        for (var i = 0; i < 1000; i++)
          NotesCompanion.insert(
            title: 'Perf note $i',
            body: Value('needle content $i'),
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    });
    insert.stop();

    final rebuild = Stopwatch()..start();
    await rebuildSearchIndex(db);
    rebuild.stop();

    final search = Stopwatch()..start();
    final hits = (await DriftSearchRepository(
      db,
    ).search('needle', limit: 50)).unwrap();
    search.stop();

    // Печатается в CI-логе как минимальный perf-smoke, без жёстких
    // миллисекундных порогов (раннеры различаются по скорости).
    // ignore: avoid_print
    print(
      'PERF notes_insert_ms=${insert.elapsedMilliseconds} '
      'index_rebuild_ms=${rebuild.elapsedMilliseconds} '
      'fts_query_ms=${search.elapsedMilliseconds} hits=${hits.length}',
    );
    expect(hits, isNotEmpty);
    expect(hits.length, lessThanOrEqualTo(50));
  });
}
