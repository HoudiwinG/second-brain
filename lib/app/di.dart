import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/secrets/secret_store.dart';
import '../core/secrets/secure_secret_store.dart';
import '../data/backup/backup_service.dart';
import '../data/db/app_database.dart';
import '../data/repositories/categories_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/ideas_repository.dart';
import '../data/repositories/llm_config_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../features/finance/domain/finance_transaction.dart';
import '../features/ideas/domain/idea_entry.dart';
import '../features/llm/data/llm_provider_factory.dart';
import '../features/llm/tools/llm_tool_registry.dart';
import '../features/notes/domain/category.dart';
import '../features/notes/domain/note.dart';
import '../features/notes/domain/tag.dart';
import '../features/reminders/application/reminder_notifier.dart';
import '../features/reminders/application/reminder_scheduler.dart';
import '../features/search/domain/search_hit.dart';
import '../features/tasks/domain/task_item.dart';
import 'desktop_services.dart';
import 'quick_hotkey.dart';
import 'router.dart';

/// DI-контейнеры Riverpod.

/// База данных приложения. Лениво открывается при первом обращении;
/// закрывается при разрушении провайдера.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return SettingsRepository(db);
});

final notesRepositoryProvider = FutureProvider<NotesRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftNotesRepository(db);
});

final categoriesRepositoryProvider = FutureProvider<CategoriesRepository>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftCategoriesRepository(db);
});

final tagsRepositoryProvider = FutureProvider<TagsRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftTagsRepository(db);
});

final tasksRepositoryProvider = FutureProvider<TasksRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftTasksRepository(db);
});

final ideasRepositoryProvider = FutureProvider<IdeasRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftIdeasRepository(db);
});

final financeRepositoryProvider = FutureProvider<FinanceRepository>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftFinanceRepository(db);
});

final searchRepositoryProvider = FutureProvider<SearchRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftSearchRepository(db);
});

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return BackupService(db);
});

/// Офлайн-история чата.
final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftChatRepository(db);
});

/// Конфигурации LLM и ключи в secure storage.
final llmConfigRepositoryProvider = FutureProvider<LlmConfigRepository>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftLlmConfigRepository(db, ref.watch(secretStoreProvider));
});

/// Фабрика LLM-провайдеров; HTTP-клиент живёт вместе с ProviderScope.
final llmProviderFactoryProvider = Provider<LlmProviderFactory>((ref) {
  final factory = LlmProviderFactory();
  ref.onDispose(factory.close);
  return factory;
});

/// Реестр инструментов LLM. На stage-03 пуст: инструменты появятся на stage-04.
final llmToolRegistryProvider = Provider<LlmToolRegistry>(
  (ref) => LlmToolRegistry(),
);

/// Хранилище секретов: secure storage (DPAPI/Keychain/Keystore).
final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

/// Роутер приложения.
final routerProvider = Provider<RouterController>((ref) => RouterController());

/// Применяет глобальную комбинацию быстрого ввода.
///
/// На не-Windows платформах (и в widget-тестах) это no-op: настройка остаётся
/// кроссплатформенной, а плагин горячих клавиш не вызывается.
typedef QuickHotkeyApplier = Future<bool> Function(QuickHotkey hotkey);

final quickHotkeyApplierProvider = Provider<QuickHotkeyApplier>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return (_) async => true;
  }
  return DesktopServices.setQuickCaptureHotkey;
});

/// Системные уведомления. На не-Windows — no-op.
final reminderNotifierProvider = Provider<ReminderNotifier>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return const NoopReminderNotifier();
  }
  return LocalReminderNotifier();
});

/// Планировщик напоминаний. На не-Windows не создаётся.
///
/// В приложении провайдер читается из `SecondBrainApp`, поэтому таймер живёт
/// столько же, сколько ProviderScope. В тестах платформа — Android, поэтому
/// фоновый таймер не запускается и не мешает `flutter_test`.
final reminderSchedulerProvider = Provider<ReminderScheduler?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;
  final repository = ref.watch(tasksRepositoryProvider.future);
  final scheduler = ReminderScheduler(
    repository: () => repository,
    notifier: ref.watch(reminderNotifierProvider),
  );
  unawaited(scheduler.start());
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
