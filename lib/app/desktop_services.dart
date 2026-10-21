import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
// tray_manager 0.5.x: классический API (трей без сбора нативных дл-б).
// Миграция на nativeapi (0.6+) — после установки полноценного C-тулчейна;
// см. ADR-006 в decisions.md.
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/logging/app_logger.dart';

/// Системная интеграция Windows: окно, трей, глобальная горячая клавиша.
///
/// Вызывается только при Platform.isWindows (см. main) — десктопные плагины
/// не инициализируются на мобильных. Требования: STAGE_ONE п.12, ТЗ модуль 13.
abstract final class DesktopServices {
  /// Глобальная горячая клавиша по умолчанию: Ctrl+Alt+B (Second Brain).
  static const String hotkeyLabel = 'Ctrl+Alt+B';

  static const String _kShowWindow = 'show_window';
  static const String _kHideWindow = 'hide_window';
  static const String _kQuit = 'quit';

  /// Инициализация: окно, трей, горячая клавиша.
  static Future<void> init() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      title: 'Second Brain',
      minimumSize: Size(900, 600),
      center: true,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await _initTray();
    await _initHotkey();
    AppLogger.d('DesktopServices: инициализация Windows завершена');
  }

  static Future<void> _initTray() async {
    try {
      await trayManager.setIcon('assets/tray_icon.png');
      await trayManager.setToolTip('Second Brain');
      await trayManager.setContextMenu(
        Menu(items: [
          MenuItem(key: _kShowWindow, label: 'Show window'),
          MenuItem(key: _kHideWindow, label: 'Hide window'),
          MenuItem.separator(),
          MenuItem(key: _kQuit, label: 'Quit'),
        ]),
      );
      trayManager.addListener(_TrayListener());
    } on Exception catch (e, s) {
      // Трей не критичен: приложение обязано работать и без него.
      AppLogger.e('DesktopServices: трей недоступен', e, s);
    }
  }

  static Future<void> _initHotkey() async {
    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      HotKey(
        key: LogicalKeyboardKey.keyB,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      ),
      keyDownHandler: (_) async {
        // Требование: горячая клавиша = «открыть окно».
        await windowManager.show();
        await windowManager.focus();
      },
    );
    AppLogger.d('DesktopServices: глобальная горячая клавиша $hotkeyLabel зарегистрирована');
  }
}

/// Обработка событий трея через legacy-API tray_manager.
class _TrayListener with TrayListener {
  @override
  void onTrayIconMouseDown() => windowManager.show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case DesktopServices._kShowWindow:
        windowManager.show();
      case DesktopServices._kHideWindow:
        windowManager.hide();
      case DesktopServices._kQuit:
        windowManager.close();
    }
  }
}
