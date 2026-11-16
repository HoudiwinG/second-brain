import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/db/app_database.dart' show AppDatabase;
import 'package:second_brain/data/repositories/learning_repository.dart';
import 'package:second_brain/features/learning/domain/learning_session.dart';
import 'package:second_brain/features/learning/domain/learning_track.dart';

import 'helpers/in_memory_db.dart';

void main() {
  late AppDatabase db;
  late DriftLearningRepository repo;

  setUp(() {
    db = InMemoryDbFactory.open();
    addTearDown(db.close);
    repo = DriftLearningRepository(db);
  });

  test('создаёт трек с roadmap, полями и приватностью', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(
        title: 'Flutter',
        goal: 'Научиться писать приложения',
        steps: [
          LearningStep(id: 's1', title: 'Dart'),
          LearningStep(
            id: 's2',
            title: 'Widgets',
            description: 'Layout и state',
            status: LearningStepStatus.inProgress,
          ),
        ],
        customFields: {'hours': '10', 'level': 'middle'},
        isPrivateForLlm: true,
      ),
    )).unwrap();

    expect(track.id, greaterThan(0));
    expect(track.steps, hasLength(2));
    expect(track.steps.last.status, LearningStepStatus.inProgress);
    expect(track.customFields, {'hours': '10', 'level': 'middle'});
    expect(track.isPrivateForLlm, isTrue);
    expect(track.progress, 0);

    final loaded = (await repo.getTrack(track.id)).unwrap()!;
    expect(loaded.steps.map((step) => step.title), ['Dart', 'Widgets']);
    expect(loaded.customFields['level'], 'middle');
  });

  test('updateTrack меняет поля и roadmap', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(title: 'Old', goal: 'Old goal'),
    )).unwrap();

    final updated = (await repo.updateTrack(
      track.id,
      const LearningTrackDraft(
        title: 'New',
        goal: 'New goal',
        steps: [LearningStep(id: 's1', title: 'Новый шаг')],
        customFields: {'level': 'advanced'},
      ),
    )).unwrap();

    expect(updated.title, 'New');
    expect(updated.goal, 'New goal');
    expect(updated.steps.single.title, 'Новый шаг');
    expect(updated.customFields['level'], 'advanced');
  });

  test('нормализует дубли id и сохраняет стабильный fallback id', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(
        title: 'Dup',
        steps: [
          LearningStep(id: 'same', title: 'A'),
          LearningStep(id: 'same', title: 'B'),
        ],
      ),
    )).unwrap();
    expect(track.steps.map((step) => step.id).toSet(), hasLength(2));

    await db.customStatement(
      "UPDATE learning_tracks SET roadmap_json = "
      "'[{\"title\":\"Legacy\"}]' WHERE id = ${track.id}",
    );
    final loaded = (await repo.getTrack(track.id)).unwrap()!;
    final fallbackId = loaded.steps.single.id;
    expect(fallbackId, 'legacy_${track.id}_0');
    final changed = (await repo.setStepStatus(
      track.id,
      fallbackId,
      LearningStepStatus.done,
    )).unwrap();
    expect(changed.completedSteps, 1);
  });

  test('повреждённый JSON не ломает чтение трека', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(title: 'Corrupt'),
    )).unwrap();
    await db.customStatement(
      "UPDATE learning_tracks SET roadmap_json = '{bad', "
      "custom_fields_json = 'not json' WHERE id = ${track.id}",
    );

    final loaded = (await repo.getTrack(track.id)).unwrap()!;
    expect(loaded.steps, isEmpty);
    expect(loaded.customFields, isEmpty);
    expect((await repo.listTracks()).unwrap(), hasLength(1));
  });

  test('обновляет шаг и считает прогресс', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(
        title: 'SQL',
        steps: [
          LearningStep(id: 's1', title: 'SELECT'),
          LearningStep(id: 's2', title: 'JOIN'),
        ],
      ),
    )).unwrap();

    final updated = (await repo.setStepStatus(
      track.id,
      's1',
      LearningStepStatus.done,
    )).unwrap();
    expect(updated.completedSteps, 1);
    expect(updated.progress, 0.5);

    final done = (await repo.setSteps(track.id, [
      ...updated.steps,
      const LearningStep(id: 's3', title: 'INDEX'),
    ])).unwrap();
    expect(done.steps, hasLength(3));
    expect(done.progress, closeTo(1 / 3, 0.001));
  });

  test('добавляет и удаляет сессии', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(title: 'Английский'),
    )).unwrap();

    final first = (await repo.addSession(
      LearningSessionDraft(
        trackId: track.id,
        durationMinutes: 40,
        notes: 'Present Simple',
        date: DateTime(2026, 11, 1, 18, 30),
      ),
    )).unwrap();
    expect(first.date.toUtc(), DateTime.utc(2026, 11, 1));
    await repo.addSession(
      LearningSessionDraft(
        trackId: track.id,
        durationMinutes: 25,
        date: DateTime.utc(2026, 11, 3),
      ),
    );

    final sessions = (await repo.listSessions(track.id)).unwrap();
    expect(sessions, hasLength(2));
    expect(sessions.first.durationMinutes, 25);
    expect(sessions.last.notes, 'Present Simple');

    (await repo.deleteSession(first.id)).unwrap();
    expect((await repo.listSessions(track.id)).unwrap(), hasLength(1));
    expect(await repo.deleteSession(999999), isA<Failure<void>>());
  });

  test('forLlm исключает приватные треки', () async {
    await repo.createTrack(
      const LearningTrackDraft(title: 'Public', goal: 'x'),
    );
    await repo.createTrack(
      const LearningTrackDraft(
        title: 'Private',
        goal: 'y',
        isPrivateForLlm: true,
      ),
    );

    final all = (await repo.listTracks()).unwrap();
    final forLlm = (await repo.listTracks(forLlm: true)).unwrap();
    expect(all, hasLength(2));
    expect(forLlm.single.title, 'Public');
  });

  test('валидация названия и длительности', () async {
    expect(
      await repo.createTrack(const LearningTrackDraft(title: '   ')),
      isA<Failure<LearningTrack>>(),
    );

    final track = (await repo.createTrack(
      const LearningTrackDraft(title: 'Валидный'),
    )).unwrap();
    expect(
      await repo.addSession(
        LearningSessionDraft(
          trackId: track.id,
          durationMinutes: 0,
          date: DateTime.utc(2026, 11, 1),
        ),
      ),
      isA<Failure<LearningSession>>(),
    );
  });

  test('softDelete скрывает трек, но не сессии', () async {
    final track = (await repo.createTrack(
      const LearningTrackDraft(title: 'Скрыть'),
    )).unwrap();
    await repo.addSession(
      LearningSessionDraft(
        trackId: track.id,
        durationMinutes: 10,
        date: DateTime.utc(2026, 11, 1),
      ),
    );

    (await repo.softDeleteTrack(track.id)).unwrap();
    (await repo.softDeleteTrack(track.id)).unwrap();

    expect((await repo.listTracks()).unwrap(), isEmpty);
    expect(
      (await repo.listTracks(includeDeleted: true)).unwrap(),
      hasLength(1),
    );
    expect((await repo.listSessions(track.id)).unwrap(), hasLength(1));
  });
}
