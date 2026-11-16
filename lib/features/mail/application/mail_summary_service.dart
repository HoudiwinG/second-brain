import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/llm_config_repository.dart';
import '../../llm/application/llm_config_controller.dart';
import '../../llm/data/llm_provider_factory.dart';
import '../../llm/domain/llm_chat.dart';
import '../../llm/domain/llm_endpoint.dart';
import '../../llm/domain/llm_message.dart';
import '../../llm/domain/llm_provider_config.dart';
import '../domain/mail_message.dart';

/// Суммаризация писем через LLM. Приватные письма не отправляются.
class MailSummaryService {
  MailSummaryService({
    required this.configs,
    required this.configRepo,
    required this.factory,
  });

  final List<LlmProviderConfig> configs;
  final LlmConfigRepository configRepo;
  final LlmProviderFactory factory;

  Future<Result<String>> summarizeMessage(MailMessage message) async {
    return summarizeMessages([message]);
  }

  Future<Result<String>> summarizeMessages(List<MailMessage> messages) async {
    if (messages.isEmpty) {
      return const Result.failure(
        ValidationException('MailSummary: нет писем для суммаризации'),
      );
    }
    if (messages.any((message) => message.isPrivateForLlm)) {
      return const Result.failure(
        ValidationException(
          'MailSummary: приватное письмо не отправляется в LLM',
        ),
      );
    }
    final config = defaultLlmConfig(configs);
    if (config == null) {
      return const Result.failure(
        ValidationException('MailSummary: сначала настройте LLM-провайдера'),
      );
    }
    final keyResult = await configRepo.readApiKey(config.id);
    if (keyResult is Failure<String?>) {
      return Result.failure(keyResult.error);
    }
    final key = (keyResult as Success<String?>).value;
    if ((key == null || key.trim().isEmpty) &&
        LlmEndpoint.requiresApiKey(config.type, config.baseUrl)) {
      return const Result.failure(
        ValidationException('MailSummary: для провайдера не задан API-ключ'),
      );
    }
    final context = messages
        .take(5)
        .map(
          (message) =>
              'От: ${message.fromAddress}\n'
              'Тема: ${message.subject}\n'
              '${message.body.isEmpty ? message.snippet : message.body}',
        )
        .join('\n\n---\n\n');
    final provider = factory.create(config: config, apiKey: key);
    final result = await provider.complete(
      LlmChatRequest(
        model: config.model,
        messages: [
          const LlmMessage(
            role: LlmRole.system,
            content:
                'Ты помощник по почте. Сделай краткое резюме письма/треда: '
                'главное, действия, сроки. Не выдумывай факты. Отвечай на '
                'русском языке.',
          ),
          LlmMessage(role: LlmRole.user, content: context),
        ],
        maxTokens: 512 < config.maxTokens ? 512 : config.maxTokens,
        temperature: 0.2,
      ),
    );
    return result.when(
      success: (response) => response.content.trim().isEmpty
          ? const Result.failure(
              LlmException('MailSummary: LLM вернул пустой ответ'),
            )
          : Result.success(response.content.trim()),
      failure: Result.failure,
    );
  }
}
