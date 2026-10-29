import '../../../../core/result/result.dart';
import '../../../search/domain/search_hit.dart';
import '../llm_tool_registry.dart';
import 'tool_args.dart';

/// Поиск по заметкам, задачам и идеям. Приватные записи исключаются всегда.
final class SearchDataTool extends LlmToolBase {
  SearchDataTool(this._search);

  final SearchRepository _search;

  static const _maxLimit = 20;

  @override
  String get name => 'search_data';

  @override
  String get description =>
      'Найти заметки, задачи и идеи пользователя по тексту. Приватные записи '
      'не возвращаются.';

  @override
  Map<String, Object?> get parameters => {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': 'Поисковая строка'},
      'limit': {
        'type': 'integer',
        'description': 'Максимум результатов, до $_maxLimit',
      },
    },
    'required': ['query'],
  };

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async {
    try {
      final query = ToolArgs.requireString(arguments, 'query');
      final requested = ToolArgs.optionalInt(arguments, 'limit') ?? 10;
      final limit = requested.clamp(1, _maxLimit);
      final hits = (await _search.search(
        query,
        forLlm: true,
        limit: limit,
      )).unwrap();
      return Result.success({
        'results': [
          for (final hit in hits)
            {
              'type': hit.type.name,
              'id': hit.entityId,
              'title': hit.title,
              'snippet': hit.snippet,
            },
        ],
      });
    } catch (error) {
      return Result.failure(toToolException(error));
    }
  }
}
