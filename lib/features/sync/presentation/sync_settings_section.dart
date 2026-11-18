import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/sync_profile.dart';

/// РќР°СЃС‚СЂРѕР№РєРё Р»РѕРєР°Р»СЊРЅС‹С… РїСЂРѕС„РёР»РµР№ sync Рё stub push/pull.
class SyncSettingsSection extends ConsumerStatefulWidget {
  const SyncSettingsSection({super.key});

  @override
  ConsumerState<SyncSettingsSection> createState() =>
      _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends ConsumerState<SyncSettingsSection> {
  Future<List<SyncProfile>>? _future;
  String? _busyProfileId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SyncProfile>> _load() async {
    final repo = await ref.read(syncProfileRepositoryProvider.future);
    return (await repo.list()).unwrap();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _create() async {
    final lcm = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lcm.syncAddProfile),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: dataFieldDecoration(lcm.syncProfileName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(lcm.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(lcm.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    final repo = await ref.read(syncProfileRepositoryProvider.future);
    final result = await repo.create(name);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _setActive(SyncProfile profile) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(syncProfileRepositoryProvider.future);
    final result = await repo.setActive(profile.id);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _delete(SyncProfile profile) async {
    final lcm = AppLocalizations.of(context)!;
    if (!await confirmDelete(context, lcm) || !mounted) return;
    final repo = await ref.read(syncProfileRepositoryProvider.future);
    final result = await repo.delete(profile.id);
    if (!mounted) return;
    result.when(
      success: (_) => _reload(),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _sync(SyncProfile profile, {required bool push}) async {
    final lcm = AppLocalizations.of(context)!;
    if (!push) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(lcm.syncPullConfirm),
          content: Text(lcm.syncPullWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(lcm.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(lcm.syncPull),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busyProfileId = profile.id);
    try {
      final service = await ref.read(syncServiceProvider.future);
      final result = push
          ? await service.push(profile)
          : await service.pull(profile);
      if (!mounted) return;
      result.when(
        success: (_) {
          if (!push) {
            ref.read(syncUndoAvailableProvider.notifier).set(true);
            ref.read(syncDataVersionProvider.notifier).bump();
          }
          _reload();
          showMessageSnackBar(context, lcm.syncSaved);
        },
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } on Object {
      if (mounted) showMessageSnackBar(context, lcm.syncError);
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _undoPull() async {
    final lcm = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lcm.syncUndoConfirm),
        content: Text(lcm.syncUndoWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(lcm.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(lcm.syncUndoPull),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyProfileId = 'undo');
    try {
      final service = await ref.read(syncServiceProvider.future);
      final result = await service.undoLastPull();
      if (!mounted) return;
      result.when(
        success: (_) {
          ref.read(syncUndoAvailableProvider.notifier).set(false);
          ref.read(syncDataVersionProvider.notifier).bump();
          _reload();
          showMessageSnackBar(context, lcm.syncSaved);
        },
        failure: (error) => showErrorSnackBar(context, lcm, error),
      );
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

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
                    lcm.syncTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: Text(lcm.syncAddProfile),
                ),
                if (ref.watch(syncUndoAvailableProvider))
                  TextButton.icon(
                    onPressed: _busyProfileId == null ? _undoPull : null,
                    icon: const Icon(Icons.undo),
                    label: Text(lcm.syncUndoPull),
                  ),
              ],
            ),
            Text(lcm.syncHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            FutureBuilder<List<SyncProfile>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text(
                    lcm.syncError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                final profiles = snapshot.data ?? const <SyncProfile>[];
                if (profiles.isEmpty) {
                  return Text(lcm.syncNoProfiles);
                }
                return Column(
                  children: [
                    for (final profile in profiles)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          profile.isActive
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_outlined,
                        ),
                        title: Text(profile.displayName),
                        subtitle: Text(
                          '${profile.isActive ? '${lcm.syncActive} В· ' : ''}'
                          '${lcm.syncLast}: '
                          '${profile.lastSyncedAt?.toLocal().toString() ?? lcm.syncNever}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (!profile.isActive)
                              IconButton(
                                tooltip: lcm.syncSetActive,
                                onPressed: () => _setActive(profile),
                                icon: const Icon(Icons.check_circle_outline),
                              ),
                            IconButton(
                              tooltip: lcm.syncPush,
                              onPressed: _busyProfileId == null
                                  ? null
                                  : () => _sync(profile, push: true),
                              icon: _busyProfileId == null
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_outlined),
                            ),
                            IconButton(
                              tooltip: lcm.syncPull,
                              onPressed: _busyProfileId == null
                                  ? null
                                  : () => _sync(profile, push: false),
                              icon: const Icon(Icons.download_outlined),
                            ),
                            IconButton(
                              tooltip: lcm.syncDelete,
                              onPressed: () => _delete(profile),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
