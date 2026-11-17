import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/feature_directions.dart';
import '../../../app/router.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/search_hit.dart';

/// Глобальный FTS5-поиск по ядру данных.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Future<List<SearchHit>>? _future;
  final Set<SearchEntityType> _types = {};
  int _days = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty) {
      setState(() => _future = null);
      return;
    }
    final repo = await ref.read(searchRepositoryProvider.future);
    if (!mounted) return;
    final from = _days == 0
        ? null
        : DateTime.now().toUtc().subtract(Duration(days: _days));
    setState(() {
      _future = repo
          .search(
            text,
            types: _types.isEmpty ? null : Set.of(_types),
            from: from,
          )
          .then((result) => result.unwrap());
    });
  }

  void _openHit(SearchHit hit) {
    final branch = switch (hit.type) {
      SearchEntityType.note => FeatureBranch.notes,
      SearchEntityType.task => FeatureBranch.tasks,
      SearchEntityType.idea => FeatureBranch.ideas,
      SearchEntityType.finance => FeatureBranch.finance,
      SearchEntityType.learning => FeatureBranch.learning,
      SearchEntityType.chat => FeatureBranch.chat,
      SearchEntityType.mail => FeatureBranch.integrations,
    };
    context.go(pathForBranch(branch));
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(lcm.navSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration:
                  dataFieldDecoration(
                    lcm.navSearch,
                    hint: lcm.searchHint,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: lcm.navSearch,
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                    ),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(lcm.searchFilters),
                FilterChip(
                  label: Text(lcm.searchAllTypes),
                  selected: _types.isEmpty,
                  onSelected: (_) {
                    setState(() => _types.clear());
                    _search();
                  },
                ),
                for (final type in SearchEntityType.values)
                  FilterChip(
                    label: Text(searchTypeLabel(lcm, type)),
                    selected: _types.contains(type),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _types.add(type);
                        } else {
                          _types.remove(type);
                        }
                      });
                      _search();
                    },
                  ),
                DropdownButton<int>(
                  value: _days,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('—')),
                    DropdownMenuItem(value: 7, child: Text('7d')),
                    DropdownMenuItem(value: 30, child: Text('30d')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _days = value);
                    _search();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _future == null
                ? Center(
                    child: Text(
                      lcm.searchPrompt,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : FutureBuilder<List<SearchHit>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ErrorState(
                          message: lcm.errorUnexpected,
                          retryLabel: lcm.retryAction,
                          onRetry: _search,
                        );
                      }
                      final hits = snapshot.data!;
                      if (hits.isEmpty) {
                        return EmptyListState(
                          icon: Icons.search_off_outlined,
                          message: lcm.searchNoResults,
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              lcm.searchResultsCount(hits.length),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: hits.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) => _SearchHitCard(
                                hit: hits[index],
                                onTap: () => _openHit(hits[index]),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchHitCard extends StatelessWidget {
  const _SearchHitCard({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(switch (hit.type) {
          SearchEntityType.note => Icons.sticky_note_2_outlined,
          SearchEntityType.task => Icons.checklist_outlined,
          SearchEntityType.idea => Icons.lightbulb_outline,
          SearchEntityType.finance => Icons.savings_outlined,
          SearchEntityType.learning => Icons.school_outlined,
          SearchEntityType.chat => Icons.forum_outlined,
          SearchEntityType.mail => Icons.mail_outline,
        }),
        title: Row(
          children: [
            Expanded(child: Text(hit.title)),
            if (hit.isPrivateForLlm) const Icon(Icons.lock_outline, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              hit.snippet.replaceAll('<<', '[').replaceAll('>>', ']'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(searchTypeLabel(lcm, hit.type)),
                  visualDensity: VisualDensity.compact,
                ),
                for (final tag in hit.tags)
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
