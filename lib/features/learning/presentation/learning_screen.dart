import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/learning_session.dart';
import '../domain/learning_track.dart';

/// Экран обучения: треки, roadmap, сессии и AI-тренер.
class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  Future<List<LearningTrack>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LearningTrack>> _load() async {
    final repo = await ref.read(learningRepositoryProvider.future);
    return (await repo.listTracks()).unwrap();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openEditor(LearningTrack? track) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<LearningTrackDraft>(
      context: context,
      builder: (_) => _TrackEditorDialog(track: track),
    );
    if (draft == null || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = track == null
        ? await repo.createTrack(draft)
        : await repo.updateTrack(track.id, draft);
    if (!mounted) return;
    result.when(
      success: (_) {
        _reload();
        showMessageSnackBar(context, lcm.learningTrackSaved);
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _delete(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.softDeleteTrack(track.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        _reload();
        showMessageSnackBar(context, lcm.learningTrackDeleted);
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _openTrack(LearningTrack track) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearningTrackScreen(trackId: track.id),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lcm.navLearning),
        actions: [
          IconButton(
            tooltip: lcm.actionRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add),
        label: Text(lcm.learningAddTrack),
      ),
      body: FutureBuilder<List<LearningTrack>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: lcm.errorUnexpected,
              retryLabel: lcm.retryAction,
              onRetry: _reload,
            );
          }
          final tracks = snapshot.data ?? const <LearningTrack>[];
          if (tracks.isEmpty) {
            return EmptyListState(
              icon: Icons.school_outlined,
              message: lcm.learningEmpty,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: tracks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return _TrackCard(
                track: track,
                onTap: () => _openTrack(track),
                onEdit: () => _openEditor(track),
                onDelete: () => _delete(track),
              );
            },
          );
        },
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LearningTrack track;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (track.isPrivateForLlm)
                          const Icon(Icons.visibility_off_outlined, size: 18),
                      ],
                    ),
                    if (track.goal.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.goal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: track.progress),
                    const SizedBox(height: 4),
                    Text(
                      lcm.learningProgress(
                        track.completedSteps,
                        track.steps.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: lcm.actionEdit,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: lcm.actionDelete,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackEditorDialog extends StatefulWidget {
  const _TrackEditorDialog({required this.track});

  final LearningTrack? track;

  @override
  State<_TrackEditorDialog> createState() => _TrackEditorDialogState();
}

class _TrackEditorDialogState extends State<_TrackEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _goal;
  late final TextEditingController _fields;
  late bool _private;
  String? _error;

  @override
  void initState() {
    super.initState();
    final track = widget.track;
    _title = TextEditingController(text: track?.title ?? '');
    _goal = TextEditingController(text: track?.goal ?? '');
    _fields = TextEditingController(
      text: (track?.customFields.entries ?? const <MapEntry<String, String>>[])
          .map((entry) => '${entry.key}=${entry.value}')
          .join('\n'),
    );
    _private = track?.isPrivateForLlm ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    _fields.dispose();
    super.dispose();
  }

  void _submit() {
    final lcm = AppLocalizations.of(context)!;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = lcm.quickCaptureRequired);
      return;
    }
    final fields = <String, String>{};
    for (final line in _fields.text.split('\n')) {
      final index = line.indexOf('=');
      if (index <= 0) continue;
      final key = line.substring(0, index).trim();
      final value = line.substring(index + 1).trim();
      if (key.isNotEmpty) fields[key] = value;
    }
    Navigator.of(context).pop(
      LearningTrackDraft(
        title: _title.text,
        goal: _goal.text,
        steps: widget.track?.steps ?? const [],
        customFields: fields,
        isPrivateForLlm: _private,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.track == null ? lcm.learningAddTrack : lcm.learningEditTrack,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: dataFieldDecoration(lcm.learningTrackTitle),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goal,
                minLines: 2,
                maxLines: 4,
                decoration: dataFieldDecoration(lcm.learningGoal),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fields,
                minLines: 2,
                maxLines: 5,
                decoration: dataFieldDecoration(
                  lcm.learningCustomFields,
                  hint: lcm.learningCustomFieldsHint,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lcm.learningPrivate),
                value: _private,
                onChanged: (value) => setState(() => _private = value),
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(lcm.actionSave)),
      ],
    );
  }
}

class _TrackData {
  const _TrackData({required this.track, required this.sessions});

  final LearningTrack track;
  final List<LearningSession> sessions;

  int get totalMinutes =>
      sessions.fold(0, (sum, session) => sum + session.durationMinutes);

  bool get needsCheckIn {
    if (sessions.isEmpty) return true;
    final last = sessions.first.date;
    return DateTime.now().difference(last).inDays >= 3;
  }
}

/// Детальный экран трека.
class LearningTrackScreen extends ConsumerStatefulWidget {
  const LearningTrackScreen({super.key, required this.trackId});

  final int trackId;

  @override
  ConsumerState<LearningTrackScreen> createState() =>
      _LearningTrackScreenState();
}

class _LearningTrackScreenState extends ConsumerState<LearningTrackScreen> {
  Future<_TrackData>? _future;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TrackData> _load() async {
    final repo = await ref.read(learningRepositoryProvider.future);
    final track = (await repo.getTrack(widget.trackId)).unwrap();
    if (track == null) {
      throw StateError('Learning track ${widget.trackId} not found');
    }
    final sessions = (await repo.listSessions(widget.trackId)).unwrap();
    return _TrackData(track: track, sessions: sessions);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<LearningTrackDraft>(
      context: context,
      builder: (_) => _TrackEditorDialog(track: track),
    );
    if (draft == null || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.updateTrack(track.id, draft);
    if (!mounted) return;
    result.when(
      success: (_) {
        _reload();
        showMessageSnackBar(context, lcm.learningTrackSaved);
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _deleteTrack(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.softDeleteTrack(track.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        showMessageSnackBar(context, lcm.learningTrackDeleted);
        Navigator.of(context).pop();
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _addStep(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    final step = await showDialog<({String title, String description})>(
      context: context,
      builder: (_) => const _StepDialog(),
    );
    if (step == null || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.setSteps(track.id, [
      ...track.steps,
      LearningStep(
        id: newLearningStepId(),
        title: step.title,
        description: step.description,
      ),
    ]);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _setStepStatus(
    LearningTrack track,
    LearningStep step,
    LearningStepStatus status,
  ) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.setStepStatus(track.id, step.id, status);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _editStep(LearningTrack track, LearningStep step) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<({String title, String description})>(
      context: context,
      builder: (_) => _StepDialog(step: step),
    );
    if (draft == null || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.setSteps(track.id, [
      for (final item in track.steps)
        if (item.id == step.id)
          item.copyWith(title: draft.title, description: draft.description)
        else
          item,
    ]);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _deleteStep(LearningTrack track, LearningStep step) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.setSteps(track.id, [
      for (final item in track.steps)
        if (item.id != step.id) item,
    ]);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _addSession(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    final draft = await showDialog<LearningSessionDraft>(
      context: context,
      builder: (_) => _SessionDialog(trackId: track.id),
    );
    if (draft == null || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.addSession(draft);
    if (!mounted) return;
    result.when(
      success: (_) {
        _reload();
        showMessageSnackBar(context, lcm.learningSessionSaved);
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _deleteSession(LearningSession session) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(learningRepositoryProvider.future);
    final result = await repo.deleteSession(session.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        _reload();
        showMessageSnackBar(context, lcm.learningSessionDeleted);
      },
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _generateRoadmap(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    if (track.goal.trim().isEmpty) {
      showMessageSnackBar(context, lcm.learningRoadmapEmptyGoal);
      return;
    }
    if (track.steps.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(lcm.learningGenerateRoadmap),
          content: Text(lcm.learningRoadmapReplace),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(lcm.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(lcm.learningReplace),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() => _aiBusy = true);
    try {
      final trainer = await ref.read(learningTrainerProvider.future);
      final result = await trainer.generateRoadmap(track);
      if (!mounted) return;
      await result.when(
        success: (steps) async {
          final repo = await ref.read(learningRepositoryProvider.future);
          final saved = await repo.setSteps(track.id, steps);
          if (!mounted) return;
          saved.when(
            success: (_) => _reload(),
            failure: (error) => showErrorSnackBar(context, lcm, error),
          );
        },
        failure: (error) async => showErrorSnackBar(context, lcm, error),
      );
    } on Object {
      if (mounted) showMessageSnackBar(context, lcm.errorUnexpected);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _suggestMaterials(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    setState(() => _aiBusy = true);
    try {
      final trainer = await ref.read(learningTrainerProvider.future);
      final result = await trainer.suggestMaterials(track);
      if (!mounted) return;
      result.when(
        success: (text) => _showTrainerText(lcm, text),
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Object {
      if (mounted) showMessageSnackBar(context, lcm.errorUnexpected);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _checkIn(LearningTrack track) async {
    final lcm = AppLocalizations.of(context)!;
    setState(() => _aiBusy = true);
    try {
      final trainer = await ref.read(learningTrainerProvider.future);
      final result = await trainer.checkIn(track);
      if (!mounted) return;
      result.when(
        success: (text) => _showTrainerText(lcm, text),
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Object {
      if (mounted) showMessageSnackBar(context, lcm.errorUnexpected);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _showTrainerText(AppLocalizations lcm, String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lcm.learningAiResult),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(lcm.actionClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return FutureBuilder<_TrackData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(lcm.navLearning)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(lcm.navLearning)),
            body: ErrorState(
              message: lcm.errorUnexpected,
              retryLabel: lcm.retryAction,
              onRetry: _reload,
            ),
          );
        }
        final data = snapshot.data!;
        final track = data.track;
        return Scaffold(
          appBar: AppBar(
            title: Text(track.title),
            actions: [
              IconButton(
                tooltip: lcm.actionEdit,
                onPressed: _aiBusy ? null : () => _edit(track),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: lcm.actionDelete,
                onPressed: _aiBusy ? null : () => _deleteTrack(track),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _SummaryCard(track: track),
              const SizedBox(height: 12),
              _AiTrainerCard(
                track: track,
                needsCheckIn: data.needsCheckIn,
                busy: _aiBusy,
                onGenerate: () => _generateRoadmap(track),
                onMaterials: () => _suggestMaterials(track),
                onCheckIn: () => _checkIn(track),
              ),
              const SizedBox(height: 12),
              _RoadmapCard(
                track: track,
                onAddStep: () => _addStep(track),
                onSetStatus: (step, status) =>
                    _setStepStatus(track, step, status),
                onEditStep: (step) => _editStep(track, step),
                onDeleteStep: (step) => _deleteStep(track, step),
              ),
              const SizedBox(height: 12),
              _SessionsCard(
                data: data,
                onAdd: () => _addSession(track),
                onDelete: _deleteSession,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.track});

  final LearningTrack track;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (track.goal.isNotEmpty) ...[
              Text(
                lcm.learningGoal,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(track.goal),
              const SizedBox(height: 12),
            ],
            LinearProgressIndicator(value: track.progress),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  lcm.learningProgress(
                    track.completedSteps,
                    track.steps.length,
                  ),
                ),
                const Spacer(),
                if (track.isPrivateForLlm)
                  Chip(
                    avatar: const Icon(Icons.visibility_off_outlined, size: 16),
                    label: Text(lcm.learningPrivate),
                  ),
              ],
            ),
            if (track.customFields.isNotEmpty) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final entry in track.customFields.entries)
                    Text('${entry.key}: ${entry.value}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiTrainerCard extends StatelessWidget {
  const _AiTrainerCard({
    required this.track,
    required this.needsCheckIn,
    required this.busy,
    required this.onGenerate,
    required this.onMaterials,
    required this.onCheckIn,
  });

  final LearningTrack track;
  final bool needsCheckIn;
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onMaterials;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final enabled = !track.isPrivateForLlm && !busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Text(
                  lcm.learningAiTrainer,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (busy) ...[
                  const Spacer(),
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            if (track.isPrivateForLlm) ...[
              const SizedBox(height: 8),
              Text(lcm.learningAiPrivate),
            ],
            if (needsCheckIn) ...[
              const SizedBox(height: 8),
              Text(lcm.learningCheckInHint),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: enabled ? onGenerate : null,
                  icon: const Icon(Icons.route_outlined),
                  label: Text(lcm.learningGenerateRoadmap),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onMaterials : null,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(lcm.learningSuggestMaterials),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onCheckIn : null,
                  icon: const Icon(Icons.question_answer_outlined),
                  label: Text(lcm.learningCheckIn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.track,
    required this.onAddStep,
    required this.onSetStatus,
    required this.onEditStep,
    required this.onDeleteStep,
  });

  final LearningTrack track;
  final VoidCallback onAddStep;
  final void Function(LearningStep, LearningStepStatus) onSetStatus;
  final ValueChanged<LearningStep> onEditStep;
  final ValueChanged<LearningStep> onDeleteStep;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lcm.learningRoadmap,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddStep,
                  icon: const Icon(Icons.add),
                  label: Text(lcm.learningAddStep),
                ),
              ],
            ),
            if (track.steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(lcm.learningNoSteps),
              )
            else
              for (final step in track.steps)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PopupMenuButton<LearningStepStatus>(
                    tooltip: lcm.learningChangeStepStatus,
                    initialValue: step.status,
                    onSelected: (status) => onSetStatus(step, status),
                    itemBuilder: (context) => [
                      for (final status in LearningStepStatus.values)
                        PopupMenuItem(
                          value: status,
                          child: Text(_stepStatusLabel(lcm, status)),
                        ),
                    ],
                    child: Icon(_stepStatusIcon(step.status)),
                  ),
                  title: Text(
                    step.title,
                    style: step.status == LearningStepStatus.done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    step.description.isEmpty
                        ? _stepStatusLabel(lcm, step.status)
                        : '${_stepStatusLabel(lcm, step.status)} · '
                              '${step.description}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: lcm.actionEdit,
                        onPressed: () => onEditStep(step),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: lcm.actionDelete,
                        onPressed: () => onDeleteStep(step),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({
    required this.data,
    required this.onAdd,
    required this.onDelete,
  });

  final _TrackData data;
  final VoidCallback onAdd;
  final ValueChanged<LearningSession> onDelete;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lcm.learningSessions,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(lcm.learningTotalMinutes(data.totalMinutes)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: lcm.learningAddSession,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (data.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(lcm.learningNoSessions),
              )
            else
              for (final session in data.sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(
                    '${formatCalendarDate(context, session.date.toUtc())} · '
                    '${lcm.learningSessionMinutes(session.durationMinutes)}',
                  ),
                  subtitle: session.notes.isEmpty ? null : Text(session.notes),
                  trailing: IconButton(
                    tooltip: lcm.actionDelete,
                    onPressed: () => onDelete(session),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StepDialog extends StatefulWidget {
  const _StepDialog({this.step});

  final LearningStep? step;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.step?.title ?? '');
    _description = TextEditingController(text: widget.step?.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final lcm = AppLocalizations.of(context)!;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = lcm.quickCaptureRequired);
      return;
    }
    Navigator.of(context)
        .pop((title: _title.text, description: _description.text));
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.learningAddStep),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: dataFieldDecoration(lcm.learningStepTitle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: dataFieldDecoration(lcm.learningStepDescription),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(lcm.actionSave)),
      ],
    );
  }
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({required this.trackId});

  final int trackId;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  final _duration = TextEditingController(text: '30');
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final lcm = AppLocalizations.of(context)!;
    final duration = int.tryParse(_duration.text.trim());
    if (duration == null || duration < 1 || duration > 1440) {
      setState(() => _error = lcm.learningDurationRange);
      return;
    }
    Navigator.of(context).pop(
      LearningSessionDraft(
        trackId: widget.trackId,
        durationMinutes: duration,
        notes: _notes.text,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.learningAddSession),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: dataFieldDecoration(lcm.learningSessionDuration),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(lcm.learningSessionDate),
              subtitle: Text(formatCalendarDate(context, _date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: dataFieldDecoration(lcm.learningSessionNotes),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(lcm.actionSave)),
      ],
    );
  }
}

String _stepStatusLabel(AppLocalizations lcm, LearningStepStatus status) =>
    switch (status) {
      LearningStepStatus.todo => lcm.learningStepTodo,
      LearningStepStatus.inProgress => lcm.learningStepInProgress,
      LearningStepStatus.done => lcm.learningStepDone,
    };

IconData _stepStatusIcon(LearningStepStatus status) => switch (status) {
  LearningStepStatus.todo => Icons.radio_button_unchecked,
  LearningStepStatus.inProgress => Icons.timelapse_outlined,
  LearningStepStatus.done => Icons.check_circle_outline,
};
