import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../features/learning/domain/learning_session.dart';
import '../../features/learning/domain/learning_track.dart';
import '../db/app_database.dart' as db;
import '../search/search_index.dart';
import 'repository_guard.dart';

/// Drift-реализация треков и сессий обучения.
class DriftLearningRepository implements LearningRepository {
  DriftLearningRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<Result<List<LearningTrack>>> listTracks({
    bool includeDeleted = false,
    bool forLlm = false,
  }) {
    return RepositoryGuard.guard('LearningRepository.listTracks', () async {
      final query = _db.select(_db.learningTracks);
      if (!includeDeleted) {
        query.where((t) => t.deletedAt.isNull());
      }
      if (forLlm) {
        query.where((t) => t.isPrivateForLlm.equals(false));
      }
      query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      final rows = await query.get();
      return [for (final row in rows) _toTrack(row)];
    });
  }

  @override
  Future<Result<LearningTrack?>> getTrack(
    int id, {
    bool includeDeleted = false,
  }) {
    return RepositoryGuard.guard('LearningRepository.getTrack', () async {
      final row = await _findTrack(id, includeDeleted: includeDeleted);
      return row == null ? null : _toTrack(row);
    });
  }

  @override
  Future<Result<LearningTrack>> createTrack(LearningTrackDraft draft) {
    return RepositoryGuard.guard('LearningRepository.createTrack', () async {
      final normalized = _validate(draft);
      final now = DateTime.now().toUtc();
      final id = await _db
          .into(_db.learningTracks)
          .insert(
            db.LearningTracksCompanion.insert(
              title: normalized.title,
              goal: Value(normalized.goal),
              roadmapJson: Value(_encodeSteps(normalized.steps)),
              customFieldsJson: Value(_encodeFields(normalized.customFields)),
              isPrivateForLlm: Value(normalized.isPrivateForLlm),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await indexLearningTrack(_db, id);
      final row = await _findTrack(id);
      return _toTrack(row!);
    });
  }

  @override
  Future<Result<LearningTrack>> updateTrack(int id, LearningTrackDraft draft) {
    return RepositoryGuard.guard('LearningRepository.updateTrack', () async {
      final current = await _findTrack(id);
      if (current == null) {
        throw ValidationException('LearningRepository: трек $id не найден');
      }
      final normalized = _validate(draft);
      await (_db.update(
        _db.learningTracks,
      )..where((t) => t.id.equals(id))).write(
        db.LearningTracksCompanion(
          title: Value(normalized.title),
          goal: Value(normalized.goal),
          roadmapJson: Value(_encodeSteps(normalized.steps)),
          customFieldsJson: Value(_encodeFields(normalized.customFields)),
          isPrivateForLlm: Value(normalized.isPrivateForLlm),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await indexLearningTrack(_db, id);
      final row = await _findTrack(id);
      return _toTrack(row!);
    });
  }

  @override
  Future<Result<LearningTrack>> setSteps(int id, List<LearningStep> steps) {
    return RepositoryGuard.guard('LearningRepository.setSteps', () async {
      final current = await _findTrack(id);
      if (current == null) {
        throw ValidationException('LearningRepository: трек $id не найден');
      }
      final normalized = _normalizeSteps(steps);
      await (_db.update(
        _db.learningTracks,
      )..where((t) => t.id.equals(id))).write(
        db.LearningTracksCompanion(
          roadmapJson: Value(_encodeSteps(normalized)),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await indexLearningTrack(_db, id);
      final row = await _findTrack(id);
      return _toTrack(row!);
    });
  }

  @override
  Future<Result<LearningTrack>> setStepStatus(
    int trackId,
    String stepId,
    LearningStepStatus status,
  ) {
    return RepositoryGuard.guard('LearningRepository.setStepStatus', () async {
      return _db.transaction(() async {
        final current = await _findTrack(trackId);
        if (current == null) {
          throw ValidationException(
            'LearningRepository: трек $trackId не найден',
          );
        }
        final track = _toTrack(current);
        var found = false;
        final steps = <LearningStep>[];
        for (final step in track.steps) {
          if (step.id == stepId) {
            found = true;
            steps.add(step.copyWith(status: status));
          } else {
            steps.add(step);
          }
        }
        if (!found) {
          throw ValidationException(
            'LearningRepository: шаг $stepId не найден',
          );
        }
        await (_db.update(
          _db.learningTracks,
        )..where((t) => t.id.equals(trackId))).write(
          db.LearningTracksCompanion(
            roadmapJson: Value(_encodeSteps(steps)),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await indexLearningTrack(_db, trackId);
        final row = await _findTrack(trackId);
        return _toTrack(row!);
      });
    });
  }

  @override
  Future<Result<void>> softDeleteTrack(int id) {
    return RepositoryGuard.guard(
      'LearningRepository.softDeleteTrack',
      () async {
        final current = await _findTrack(id, includeDeleted: true);
        if (current == null) {
          throw ValidationException('LearningRepository: трек $id не найден');
        }
        if (current.deletedAt != null) return;
        final now = DateTime.now().toUtc();
        await (_db.update(
          _db.learningTracks,
        )..where((t) => t.id.equals(id))).write(
          db.LearningTracksCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await indexLearningTrack(_db, id);
      },
    );
  }

  @override
  Future<Result<List<LearningSession>>> listSessions(int trackId) {
    return RepositoryGuard.guard('LearningRepository.listSessions', () async {
      final rows =
          await (_db.select(_db.learningSessions)
                ..where((s) => s.trackId.equals(trackId))
                ..orderBy([
                  (s) => OrderingTerm.desc(s.date),
                  (s) => OrderingTerm.desc(s.id),
                ]))
              .get();
      return [for (final row in rows) _toSession(row)];
    });
  }

  @override
  Future<Result<LearningSession>> addSession(LearningSessionDraft draft) {
    return RepositoryGuard.guard('LearningRepository.addSession', () async {
      if (draft.durationMinutes < 1 || draft.durationMinutes > 1440) {
        throw const ValidationException(
          'LearningRepository: длительность должна быть от 1 до 1440 минут',
        );
      }
      final track = await _findTrack(draft.trackId);
      if (track == null) {
        throw ValidationException(
          'LearningRepository: трек ${draft.trackId} не найден',
        );
      }
      final now = DateTime.now().toUtc();
      // Сессия — календарная дата, а не момент времени: храним UTC-полночь.
      final date = DateTime.utc(
        draft.date.year,
        draft.date.month,
        draft.date.day,
      );
      final id = await _db.transaction(() async {
        final id = await _db
            .into(_db.learningSessions)
            .insert(
              db.LearningSessionsCompanion.insert(
                trackId: draft.trackId,
                durationMinutes: draft.durationMinutes,
                notes: Value(draft.notes.trim()),
                date: date,
                createdAt: now,
              ),
            );
        await (_db.update(_db.learningTracks)
              ..where((t) => t.id.equals(draft.trackId)))
            .write(db.LearningTracksCompanion(updatedAt: Value(now)));
        return id;
      });
      final row = await (_db.select(
        _db.learningSessions,
      )..where((s) => s.id.equals(id))).getSingle();
      return _toSession(row);
    });
  }

  @override
  Future<Result<void>> deleteSession(int id) {
    return RepositoryGuard.guard('LearningRepository.deleteSession', () async {
      await _db.transaction(() async {
        final row = await (_db.select(
          _db.learningSessions,
        )..where((s) => s.id.equals(id))).getSingleOrNull();
        if (row == null) {
          throw ValidationException(
            'LearningRepository: сессия $id не найдена',
          );
        }
        await (_db.delete(
          _db.learningSessions,
        )..where((s) => s.id.equals(id))).go();
        await (_db.update(
          _db.learningTracks,
        )..where((t) => t.id.equals(row.trackId))).write(
          db.LearningTracksCompanion(updatedAt: Value(DateTime.now().toUtc())),
        );
      });
    });
  }

  Future<db.LearningTrack?> _findTrack(int id, {bool includeDeleted = false}) {
    final query = _db.select(_db.learningTracks)..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  static LearningTrackDraft _validate(LearningTrackDraft draft) {
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ValidationException(
        'LearningRepository: название трека не может быть пустым',
      );
    }
    if (title.length > 200) {
      throw const ValidationException(
        'LearningRepository: название трека слишком длинное',
      );
    }
    final goal = draft.goal.trim();
    if (goal.length > 5000) {
      throw const ValidationException(
        'LearningRepository: цель трека слишком длинная',
      );
    }
    final fields = <String, String>{};
    for (final entry in draft.customFields.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      if (key.length > 64 || entry.value.length > 500) {
        throw const ValidationException(
          'LearningRepository: пользовательское поле слишком длинное',
        );
      }
      if (fields.length >= 50) {
        throw const ValidationException(
          'LearningRepository: слишком много пользовательских полей',
        );
      }
      fields[key] = entry.value.trim();
    }
    return LearningTrackDraft(
      title: title,
      goal: goal,
      steps: _normalizeSteps(draft.steps),
      customFields: fields,
      isPrivateForLlm: draft.isPrivateForLlm,
    );
  }

  static List<LearningStep> _normalizeSteps(List<LearningStep> steps) {
    if (steps.length > 100) {
      throw const ValidationException(
        'LearningRepository: слишком много шагов roadmap',
      );
    }
    final ids = <String>{};
    final result = <LearningStep>[];
    for (final step in steps) {
      final title = step.title.trim();
      if (title.isEmpty) continue;
      if (title.length > 200 || step.description.length > 2000) {
        throw const ValidationException(
          'LearningRepository: шаг roadmap слишком длинный',
        );
      }
      var id = step.id.trim();
      if (id.isEmpty || ids.contains(id)) {
        do {
          id = newLearningStepId();
        } while (!ids.add(id));
      } else {
        ids.add(id);
      }
      result.add(
        LearningStep(
          id: id,
          title: title,
          description: step.description.trim(),
          status: step.status,
        ),
      );
    }
    return result;
  }

  static String _encodeSteps(List<LearningStep> steps) =>
      jsonEncode([for (final step in steps) step.toJson()]);

  static String _encodeFields(Map<String, String> fields) => jsonEncode(fields);

  static LearningTrack _toTrack(db.LearningTrack row) {
    final steps = <LearningStep>[];
    try {
      final decoded = jsonDecode(row.roadmapJson);
      if (decoded is List) {
        for (var index = 0; index < decoded.length; index++) {
          final step = LearningStep.fromJson(
            decoded[index],
            fallbackId: 'legacy_${row.id}_$index',
          );
          if (step != null) steps.add(step);
        }
      }
    } on FormatException {
      // Повреждённый JSON не должен ломать список треков.
    }
    final fields = <String, String>{};
    try {
      final decoded = jsonDecode(row.customFieldsJson);
      if (decoded is Map<String, Object?>) {
        for (final entry in decoded.entries) {
          if (entry.value is String) fields[entry.key] = entry.value as String;
        }
      }
    } on FormatException {
      // Повреждённый JSON полей игнорируется.
    }
    return LearningTrack(
      id: row.id,
      title: row.title,
      goal: row.goal,
      steps: steps,
      customFields: fields,
      isPrivateForLlm: row.isPrivateForLlm,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static LearningSession _toSession(db.LearningSession row) => LearningSession(
    id: row.id,
    trackId: row.trackId,
    durationMinutes: row.durationMinutes,
    notes: row.notes,
    date: row.date,
    createdAt: row.createdAt,
  );
}
