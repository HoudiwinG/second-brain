import 'dart:convert';

import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/llm_config_repository.dart';
import '../../llm/application/llm_config_controller.dart';
import '../../llm/data/llm_provider_factory.dart';
import '../../llm/domain/llm_chat.dart';
import '../../llm/domain/llm_endpoint.dart';
import '../../llm/domain/llm_message.dart';
import '../../llm/domain/llm_provider_config.dart';
import '../domain/learning_track.dart';

/// AI-тренер обучения: roadmap, материалы и check-in через выбранного
/// провайдера. Приватные треки не отправляются в LLM.
final class LearningTrainer {
  LearningTrainer({
    required this.configs,
    required this.configRepo,
    required this.factory,
  });

  final List<LlmProviderConfig> configs;
  final LlmConfigRepository configRepo;
  final LlmProviderFactory factory;

  Future<Result<List<LearningStep>>> generateRoadmap(
    String goal, {
    int stepCount = 6,
  }) async {
    final normalized = goal.trim();
    if (normalized.isEmpty) {
      return const Result.failure(
        ValidationException('Learning: цель не может быть пустой'),
      );
    }
    final prepared = await _prepare(
      'Ты AI-тренер. Составь roadmap обучения по цели. '
          'Верни ТОЛЬКО JSON-массив объектов вида '
          '{"title":"...","description":"..."} без markdown и пояснений. '
          'Шаги должны быть конкретными, измеримыми и идти по порядку.',
      'Цель: $normalized\nКоличество шагов: $stepCount',
      maxTokens: 2048,
    );
    if (prepared is Failure<_PreparedRequest>) {
      return Result.failure(prepared.error);
    }
    final request = (prepared as Success<_PreparedRequest>).value;
    final response = await _complete(request);
    return response.when(
      success: (answer) => _parseRoadmap(answer.content, stepCount),
      failure: Result.failure,
    );
  }

  Future<Result<String>> suggestMaterials(LearningTrack track) async {
    if (track.isPrivateForLlm) {
      return const Result.failure(
        ValidationException('Learning: приватный трек не отправляется в LLM'),
      );
    }
    final prepared = await _prepare(
      'Ты AI-тренер. Предложи 3-5 конкретных материалов или упражнений '
      'для движения по roadmap. Кратко объясни, зачем каждый нужен. '
      'Не выдумывай ссылки; если ссылки нет, опиши тип материала.',
      _trackContext(track),
      maxTokens: 1024,
    );
    if (prepared is Failure<_PreparedRequest>) {
      return Result.failure(prepared.error);
    }
    final response = await _complete(
      (prepared as Success<_PreparedRequest>).value,
    );
    return response.when(
      success: (answer) => answer.content.trim().isEmpty
          ? const Result.failure(
              LlmException('Learning: тренер вернул пустой ответ'),
            )
          : Result.success(answer.content.trim()),
      failure: Result.failure,
    );
  }

  Future<Result<String>> checkIn(LearningTrack track) async {
    if (track.isPrivateForLlm) {
      return const Result.failure(
        ValidationException('Learning: приватный трек не отправляется в LLM'),
      );
    }
    final prepared = await _prepare(
      'Ты AI-тренер. Задай 2-3 коротких вопроса о текущем прогрессе '
      'и предложи следующий маленький шаг. Не повторяй весь roadmap.',
      _trackContext(track),
      maxTokens: 700,
    );
    if (prepared is Failure<_PreparedRequest>) {
      return Result.failure(prepared.error);
    }
    final response = await _complete(
      (prepared as Success<_PreparedRequest>).value,
    );
    return response.when(
      success: (answer) => answer.content.trim().isEmpty
          ? const Result.failure(
              LlmException('Learning: тренер вернул пустой ответ'),
            )
          : Result.success(answer.content.trim()),
      failure: Result.failure,
    );
  }

  Future<Result<_PreparedRequest>> _prepare(
    String system,
    String user, {
    required int maxTokens,
  }) async {
    final config = defaultLlmConfig(configs);
    if (config == null) {
      return const Result.failure(
        ValidationException('Learning: сначала настройте LLM-провайдера'),
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
        ValidationException('Learning: для провайдера не задан API-ключ'),
      );
    }
    final limit = maxTokens < config.maxTokens ? maxTokens : config.maxTokens;
    return Result.success(
      _PreparedRequest(
        config: config,
        apiKey: key,
        request: LlmChatRequest(
          model: config.model,
          messages: [
            LlmMessage(role: LlmRole.system, content: system),
            LlmMessage(role: LlmRole.user, content: user),
          ],
          maxTokens: limit,
          temperature: 0.4,
        ),
      ),
    );
  }

  Future<Result<LlmResponse>> _complete(_PreparedRequest prepared) {
    final provider = factory.create(
      config: prepared.config,
      apiKey: prepared.apiKey,
    );
    return provider.complete(prepared.request);
  }

  static Result<List<LearningStep>> _parseRoadmap(
    String raw,
    int requestedCount,
  ) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      text = firstNewline >= 0 ? text.substring(firstNewline + 1) : text;
      if (text.endsWith('```')) text = text.substring(0, text.length - 3);
    }
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) {
      return const Result.failure(
        LlmException('Learning: тренер вернул roadmap без JSON-массива'),
      );
    }
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! List) {
        return const Result.failure(
          LlmException('Learning: некорректный roadmap'),
        );
      }
      final steps = <LearningStep>[];
      final limit = requestedCount.clamp(1, 20);
      for (final item in decoded) {
        final step = LearningStep.fromJson(item);
        if (step != null) steps.add(step);
        if (steps.length >= limit) break;
      }
      if (steps.isEmpty) {
        return const Result.failure(
          LlmException('Learning: roadmap не содержит шагов'),
        );
      }
      return Result.success(steps);
    } on FormatException {
      return const Result.failure(
        LlmException('Learning: некорректный JSON roadmap'),
      );
    }
  }

  static String _trackContext(LearningTrack track) {
    final steps = track.steps
        .map(
          (step) =>
              '- [${step.status.dbValue}] ${step.title}'
              '${step.description.isEmpty ? '' : ': ${step.description}'}',
        )
        .join('\n');
    return 'Трек: ${track.title}\n'
        'Цель: ${track.goal}\n'
        'Прогресс: ${track.completedSteps}/${track.steps.length}\n'
        'Шаги:\n$steps';
  }
}

final class _PreparedRequest {
  const _PreparedRequest({
    required this.config,
    required this.apiKey,
    required this.request,
  });

  final LlmProviderConfig config;
  final String? apiKey;
  final LlmChatRequest request;
}
