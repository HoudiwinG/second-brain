import 'package:flutter/foundation.dart';
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

  static bool _trayReady = false;

  /// Инициализация окна и горячей клавиши.
  ///
  /// Трей поднимается отдельно в [setTrayLabels]: его подписи локализованы,
  /// а [AppLocalizations] доступны только внутри MaterialApp.
  static Future<void> init() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      // Стартовый заголовок до применения локализации; appTitle в ARB
      // совпадает с названием продукта для RU/EN.
      title: 'Second Brain',
      minimumSize: Size(900, 600),
      center: true,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await _initHotkey();
    AppLogger.d('DesktopServices: окно и горячая клавиша инициализированы');
  }

  /// Обновляет локализованные подписи трея и заголовок окна.
  ///
  /// Вызывается из UI после появления [AppLocalizations] и повторно при смене
  /// языка. Идемпотентен: слушатель трея регистрируется один раз, меню и
  /// подписи обновляются при каждом вызове (TD-02).
  static Future<void> setTrayLabels({
    required String windowTitle,
    required String tooltip,
    required String showWindow,
    required String hideWindow,
    required String quit,
  }) async {
    try {
      await windowManager.setTitle(windowTitle);
      // Windows tray_manager грузит иконку через LoadImage(IMAGE_ICON),
      // который не поддерживает PNG — на Windows обязателен .ico (R00-003).
      final iconPath = defaultTargetPlatform == TargetPlatform.windows
          ? 'assets/tray_icon.ico'
          : 'assets/tray_icon.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip(tooltip);
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _kShowWindow, label: showWindow),
            MenuItem(key: _kHideWindow, label: hideWindow),
            MenuItem.separator(),
            MenuItem(key: _kQuit, label: quit),
          ],
        ),
      );
      if (!_trayReady) {
        _trayReady = true;
        // trayManager хранит ссылку на слушателя сам.
        trayManager.addListener(_TrayListener());
      }
      AppLogger.d('DesktopServices: подписи трея обновлены');
    } on Exception catch (e, s) {
      // Трей не критичен: приложение обязано работать и без него.
      AppLogger.e('DesktopServices: трей недоступен', e, s);
    }
  }

  /// Регистрирует глобальную горячую клавишу.
  ///
  /// Ошибка (например, комбинация занята другим приложением) логируется и не
  /// прерывает запуск приложения (TD-03).
  static Future<void> _initHotkey() async {
    try {
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
      AppLogger.d(
        'DesktopServices: глобальная горячая клавиша $hotkeyLabel зарегистрирована',
      );
    } on Exception catch (e, s) {
      AppLogger.e(
        'DesktopServices: не удалось зарегистрировать $hotkeyLabel',
        e,
        s,
      );
    }
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
