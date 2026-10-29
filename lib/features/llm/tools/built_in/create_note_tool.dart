import '../../../../core/result/result.dart';
import '../../../notes/domain/note.dart';
import '../llm_tool_registry.dart';
import 'tool_args.dart';

/// Создание заметки.
final class CreateNoteTool extends LlmToolBase {
  CreateNoteTool(this._notes);

  final NotesRepository _notes;

  @override
  String get name => 'create_note';

  @override
  String get description => 'Создать заметку с заголовком и текстом.';

  @override
  Map<String, Object?> get parameters => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': 'Заголовок заметки'},
      'body': {'type': 'string', 'description': 'Текст заметки'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'is_private': {
        'type': 'boolean',
        'description': 'Скрыть заметку от будущих запросов ассистента',
      },
    },
    'required': ['title'],
  };

  @override
  Future<Result<Map<String, Object?>>> execute(
    Map<String, Object?> arguments,
  ) async {
    try {
      final draft = NoteDraft(
        title: ToolArgs.requireString(arguments, 'title'),
        body: ToolArgs.optionalString(arguments, 'body') ?? '',
        tags: ToolArgs.optionalStringList(arguments, 'tags'),
        isPrivateForLlm: ToolArgs.optionalBool(arguments, 'is_private'),
      );
      final created = (await _notes.create(draft)).unwrap();
      return Result.success({'id': created.id, 'title': created.title});
    } catch (error) {
      return Result.failure(toToolException(error));
    }
  }
}
