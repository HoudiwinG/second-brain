import 'dart:async';

import 'quick_hotkey.dart';

/// Web-заглушка системной интеграции Windows.
///
/// На web нет трея, окна и глобальных горячих клавиш; методы остаются
/// no-op, чтобы общий UI компилировался.
abstract final class DesktopServices {
  static final StreamController<void> _quickCaptureRequests =
      StreamController<void>.broadcast();

  static Stream<void> get quickCaptureRequests => _quickCaptureRequests.stream;

  static Future<void> init() async {}

  static Future<bool> setQuickCaptureHotkey(QuickHotkey binding) async => true;

  static Future<void> setTrayLabels({
    required String windowTitle,
    required String tooltip,
    required String quickCapture,
    required String showWindow,
    required String hideWindow,
    required String quit,
  }) async {}
}
