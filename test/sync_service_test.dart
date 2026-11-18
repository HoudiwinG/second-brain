import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/core/sync/sync_service.dart';
import 'package:second_brain/data/backup/backup_service.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/sync/data/sync_profile_repository.dart';
import 'package:second_brain/features/sync/domain/sync_backend.dart';

import 'helpers/in_memory_db.dart';

void main() {
  test('stub sync: push/pull восстанавливает снимок', () async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    final profiles = SyncProfileRepository(settings);
    final profile = (await profiles.create('Local')).unwrap();
    final notes = DriftNotesRepository(db);

    await notes.create(const NoteDraft(title: 'Sync note', body: 'body'));
    final service = LocalSyncService(
      backup: BackupService(db),
      backend: StubSyncBackend(),
      profiles: profiles,
    );

    expect(await service.push(profile), isA<Success<void>>());
    final first = (await notes.list()).unwrap().single;
    await notes.softDelete(first.id);
    expect((await notes.list()).unwrap(), isEmpty);

    expect(await service.pull(profile), isA<Success<void>>());
    final restored = (await notes.list()).unwrap();
    expect(restored.single.title, 'Sync note');

    // Undo возвращает локальное состояние до pull (заметка была soft-deleted).
    expect(await service.undoLastPull(), isA<Success<void>>());
    expect((await notes.list()).unwrap(), isEmpty);

    final updated = (await profiles.list()).unwrap().single;
    expect(updated.lastSyncedAt, isNotNull);
  });

  test('pull без снимка и неизвестный профиль возвращают ошибку', () async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final profiles = SyncProfileRepository(SettingsRepository(db));
    final profile = (await profiles.create('Empty')).unwrap();
    final service = LocalSyncService(
      backup: BackupService(db),
      backend: StubSyncBackend(),
      profiles: profiles,
    );

    expect(await service.pull(profile), isA<Failure<void>>());
    expect(await service.undoLastPull(), isA<Failure<void>>());
    expect(await profiles.setActive('missing'), isA<Failure<void>>());
  });

  test('профили хранятся локально и активный один', () async {
    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final repo = SyncProfileRepository(SettingsRepository(db));
    final first = (await repo.create('A')).unwrap();
    final second = (await repo.create('B')).unwrap();
    expect((await repo.list()).unwrap(), hasLength(2));

    await repo.setActive(second.id).then((r) => r.unwrap());
    final list = (await repo.list()).unwrap();
    expect(list.singleWhere((p) => p.isActive).id, second.id);
    expect(list.first.id, first.id);
  });
}
