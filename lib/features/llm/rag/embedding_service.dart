import '../../../core/result/result.dart';

/// Сервис построения эмбеддингов для RAG.
///
/// Реализация поверх [LlmProvider.embed] появится при индексации заметок.
/// Интерфейс уже отделён от провайдера, чтобы RAG не зависел от конкретного
/// API и мог использовать локальную модель.
abstract interface class EmbeddingService {
  Future<Result<List<double>>> embed(String text);

  Future<Result<List<List<double>>>> embedBatch(List<String> texts);
}
