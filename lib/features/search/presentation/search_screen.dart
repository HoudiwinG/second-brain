import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
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
    setState(() {
      _future = repo.search(text).then((result) => result.unwrap());
    });
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
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: hits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _SearchHitCard(hit: hits[index]),
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
  const _SearchHitCard({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: Icon(switch (hit.type) {
          SearchEntityType.note => Icons.sticky_note_2_outlined,
          SearchEntityType.task => Icons.checklist_outlined,
          SearchEntityType.idea => Icons.lightbulb_outline,
          SearchEntityType.finance => Icons.savings_outlined,
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
