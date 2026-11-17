import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/data_ui.dart';
import '../../../core/result/result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../notes/domain/note.dart';
import '../domain/idea_entry.dart';
import '../domain/idea_search.dart';

/// Поиск статей и изображений с сохранением результатов в идеи/заметки.
class IdeaSearchDialog extends ConsumerStatefulWidget {
  const IdeaSearchDialog({super.key});

  @override
  ConsumerState<IdeaSearchDialog> createState() => _IdeaSearchDialogState();
}

class _IdeaSearchDialogState extends ConsumerState<IdeaSearchDialog> {
  final _query = TextEditingController();
  var _searching = false;
  String? _error;
  List<ArticleSearchResult> _articles = const [];
  List<ImageSearchResult> _images = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final lcm = AppLocalizations.of(context)!;
    final text = _query.text.trim();
    if (text.isEmpty) {
      setState(() => _error = lcm.ideasSearchError);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final articleService = ref.read(articleSearchServiceProvider);
      final imageService = ref.read(imageSearchServiceProvider);
      final articles = await articleService.search(text);
      final images = await imageService.search(text);
      if (!mounted) return;
      setState(() {
        _articles = articles.when(
          success: (items) => items,
          failure: (_) => const [],
        );
        _images = images.when(
          success: (items) => items,
          failure: (_) => const [],
        );
        _error =
            articles is Failure<List<ArticleSearchResult>> &&
                images is Failure<List<ImageSearchResult>>
            ? lcm.ideasSearchError
            : null;
      });
    } on Object {
      if (mounted) setState(() => _error = lcm.ideasSearchError);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _saveIdea({required String text, required String source}) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(ideasRepositoryProvider.future);
    final result = await repo.create(
      IdeaDraft(text: text, source: source, tags: const ['idea-search']),
    );
    if (!mounted) return;
    result.when(
      success: (_) => showMessageSnackBar(context, lcm.ideasSearchSaved),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  Future<void> _saveNote({
    required String title,
    required String body,
    required String source,
  }) async {
    final lcm = AppLocalizations.of(context)!;
    final repo = await ref.read(notesRepositoryProvider.future);
    final result = await repo.create(
      NoteDraft(
        title: title,
        body: '$body\n\n$source',
        tags: const ['idea-search'],
      ),
    );
    if (!mounted) return;
    result.when(
      success: (_) => showMessageSnackBar(context, lcm.ideasSearchSaved),
      failure: (error) => showErrorSnackBar(context, lcm, error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(lcm.ideasSearchTitle),
      content: SizedBox(
        width: 820,
        height: 560,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TextField(
                controller: _query,
                autofocus: true,
                decoration: dataFieldDecoration(lcm.ideasSearchHint),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _searching ? lcm.ideasSearching : lcm.ideasSearchAction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_error != null)
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.article_outlined)),
                  Tab(icon: Icon(Icons.image_outlined)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ArticleResults(
                      results: _articles,
                      onSaveIdea: (result) => _saveIdea(
                        text: _articleIdeaText(result),
                        source: result.url,
                      ),
                      onSaveNote: (result) => _saveNote(
                        title: result.title,
                        body: result.summary,
                        source: result.url,
                      ),
                    ),
                    _ImageResults(
                      results: _images,
                      onSaveIdea: (result) => _saveIdea(
                        text: _imageIdeaText(result),
                        source: result.imageUrl,
                      ),
                      onSaveNote: (result) => _saveNote(
                        title: result.title,
                        body: result.attribution.isEmpty
                            ? '![${result.title}](${result.imageUrl})'
                            : '![${result.title}](${result.imageUrl})\n\n'
                                  '${result.attribution}',
                        source: result.pageUrl ?? result.imageUrl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lcm.actionClose),
        ),
      ],
    );
  }

  static String _articleIdeaText(ArticleSearchResult result) => [
    result.title,
    result.summary,
    result.url,
  ].where((part) => part.trim().isNotEmpty).join('\n\n');

  static String _imageIdeaText(ImageSearchResult result) => [
    result.title,
    if (result.attribution.isNotEmpty) result.attribution,
    result.pageUrl ?? result.imageUrl,
  ].join('\n');
}

class _ArticleResults extends StatelessWidget {
  const _ArticleResults({
    required this.results,
    required this.onSaveIdea,
    required this.onSaveNote,
  });

  final List<ArticleSearchResult> results;
  final ValueChanged<ArticleSearchResult> onSaveIdea;
  final ValueChanged<ArticleSearchResult> onSaveNote;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    if (results.isEmpty) {
      return Center(child: Text(lcm.ideasSearchEmpty));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          title: Text(result.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.source),
              if (result.summary.isNotEmpty)
                Text(
                  result.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => onSaveIdea(result),
                child: Text(lcm.ideasSaveIdea),
              ),
              TextButton(
                onPressed: () => onSaveNote(result),
                child: Text(lcm.ideasSaveNote),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImageResults extends StatelessWidget {
  const _ImageResults({
    required this.results,
    required this.onSaveIdea,
    required this.onSaveNote,
  });

  final List<ImageSearchResult> results;
  final ValueChanged<ImageSearchResult> onSaveIdea;
  final ValueChanged<ImageSearchResult> onSaveNote;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    if (results.isEmpty) {
      return Center(child: Text(lcm.ideasSearchEmpty));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          leading: SizedBox(
            width: 56,
            height: 56,
            child: Image.network(
              result.thumbnailUrl ?? result.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
            ),
          ),
          title: Text(result.title),
          subtitle: Text(
            [
              result.source,
              if (result.attribution.isNotEmpty) result.attribution,
            ].join(' · '),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => onSaveIdea(result),
                child: Text(lcm.ideasSaveIdea),
              ),
              TextButton(
                onPressed: () => onSaveNote(result),
                child: Text(lcm.ideasSaveNote),
              ),
            ],
          ),
        );
      },
    );
  }
}
