import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/reminder_message.dart';

/// Показывает системное уведомление о задаче.
abstract interface class ReminderNotifier {
  Future<void> show(ReminderMessage message);
}

/// Заглушка для тестов и не-Windows платформ.
class NoopReminderNotifier implements ReminderNotifier {
  const NoopReminderNotifier();

  @override
  Future<void> show(ReminderMessage message) async {}
}

/// Windows-уведомления через WinToast (local_notifier).
class LocalReminderNotifier implements ReminderNotifier {
  static var _initialized = false;

  /// Инициализирует WinToast один раз за запуск приложения.
  static Future<void> initialize() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    try {
      await localNotifier.setup(
        appName: 'Second Brain',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
      AppLogger.d('ReminderNotifier: Windows-уведомления инициализированы');
    } on Object catch (e, s) {
      // Уведомления не должны мешать запуску приложения.
      AppLogger.e('ReminderNotifier: не удалось инициализировать', e, s);
    }
  }

  @override
  Future<void> show(ReminderMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    await initialize();
    if (!_initialized) return;

    try {
      final notification = LocalNotification(
        identifier: 'task-${message.taskId}',
        title: 'Second Brain',
        subtitle: message.title,
        body: message.body.trim().isEmpty ? null : message.body,
      );
      notification.onClick = () {
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
      };
      notification.onClose = (_) => unawaited(notification.destroy());
      await notification.show();
      AppLogger.d('ReminderNotifier: показано напоминание task-${message.taskId}');
    } on Object catch (e, s) {
      AppLogger.e('ReminderNotifier: не удалось показать уведомление', e, s);
    }
  }
}
