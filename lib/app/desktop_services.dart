import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
// tray_manager 0.5.x: классический API (трей без сбора нативных дл-б).
// Миграция на nativeapi (0.6+) — после установки полноценного C-тулчейна;
// см. ADR-006 в decisions.md.
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/logging/app_logger.dart';
import 'quick_hotkey.dart';

/// Системная интеграция Windows: окно, трей, глобальная горячая клавиша.
///
/// Вызывается только при Platform.isWindows (см. main) — десктопные плагины
/// не инициализируются на мобильных. Требования: STAGE_ONE п.12, ТЗ модуль 13,
/// stage-02 — быстрый ввод из трея/хоткея и закрытие в трей.
abstract final class DesktopServices {
  static const String _kQuickCapture = 'quick_capture';
  static const String _kShowWindow = 'show_window';
  static const String _kHideWindow = 'hide_window';
  static const String _kQuit = 'quit';

  static bool _trayReady = false;
  static bool _windowListenerReady = false;
  static bool _quitting = false;
  static QuickHotkey? _currentHotkey;

  static final StreamController<void> _quickCaptureRequests =
      StreamController<void>.broadcast();

  /// События запроса быстрого ввода (из хоткея или меню трея).
  static Stream<void> get quickCaptureRequests => _quickCaptureRequests.stream;

  /// Путь к иконке трея в комплекте приложения.
  ///
  /// tray_manager на Windows передаёт путь в `LoadImage(..., LR_LOADFROMFILE)`,
  /// поэтому путь обязан быть абсолютным и указывать на каталог `.exe`, а не
  /// на текущий рабочий каталог процесса (R02-001). Файл иконки лежит в
  /// `data/flutter_assets/assets/tray_icon.ico` рядом с исполняемым файлом.
  @visibleForTesting
  static String trayIconPath({
    TargetPlatform? platform,
    String? executablePath,
  }) {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.windows) return 'assets/tray_icon.png';

    final executable = executablePath ?? Platform.resolvedExecutable;
    final directory = File(executable).parent.path;
    return [
      directory,
      'data',
      'flutter_assets',
      'assets',
      'tray_icon.ico',
    ].join(Platform.pathSeparator);
  }

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

    if (!_windowListenerReady) {
      _windowListenerReady = true;
      windowManager.addListener(_WindowListener());
    }

    await setQuickCaptureHotkey(QuickHotkey.defaultBinding);
    AppLogger.d('DesktopServices: окно и горячая клавиша инициализированы');
  }

  /// Регистрирует глобальную комбинацию быстрого ввода.
  ///
  /// Возвращает false, если комбинация занята другим приложением или плагин
  /// недоступен. Ошибка не прерывает запуск (TD-03).
  static Future<bool> setQuickCaptureHotkey(QuickHotkey binding) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return true;
    }
    try {
      await hotKeyManager.unregisterAll();
      await hotKeyManager.register(
        binding.toHotKey(),
        keyDownHandler: (_) => unawaited(requestQuickCapture()),
      );
      _currentHotkey = binding;
      AppLogger.d(
        'DesktopServices: горячая клавиша ${binding.label} зарегистрирована',
      );
      return true;
    } on Exception catch (e, s) {
      AppLogger.e(
        'DesktopServices: не удалось зарегистрировать ${binding.label}',
        e,
        s,
      );
      // Старая комбинация уже снята — возвращаем её, чтобы не потерять
      // глобальный быстрый ввод из-за занятой новой комбинации.
      final previous = _currentHotkey;
      if (previous != null) {
        try {
          await hotKeyManager.register(
            previous.toHotKey(),
            keyDownHandler: (_) => unawaited(requestQuickCapture()),
          );
          _currentHotkey = previous;
        } on Exception catch (restoreError, restoreStack) {
          _currentHotkey = null;
          AppLogger.e(
            'DesktopServices: не удалось восстановить ${previous.label}',
            restoreError,
            restoreStack,
          );
        }
      }
      return false;
    }
  }

  /// Показывает окно и просит UI открыть диалог быстрого ввода.
  static Future<void> requestQuickCapture() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } on Exception catch (e, s) {
      // Окно могло быть уже уничтожено при выходе.
      AppLogger.e('DesktopServices: не удалось показать окно', e, s);
    }
    if (!_quickCaptureRequests.isClosed) {
      _quickCaptureRequests.add(null);
    }
  }

  /// Обновляет локализованные подписи трея и заголовок окна.
  ///
  /// Вызывается из UI после появления [AppLocalizations] и повторно при смене
  /// языка. Идемпотентен: слушатель трея регистрируется один раз, меню и
  /// подписи обновляются при каждом вызове (TD-02).
  static Future<void> setTrayLabels({
    required String windowTitle,
    required String tooltip,
    required String quickCapture,
    required String showWindow,
    required String hideWindow,
    required String quit,
  }) async {
    try {
      await windowManager.setTitle(windowTitle);
      // Windows tray_manager грузит иконку через LoadImage(IMAGE_ICON),
      // который не поддерживает PNG — на Windows обязателен .ico (R00-003).
      final iconPath = trayIconPath();
      if (defaultTargetPlatform == TargetPlatform.windows &&
          !File(iconPath).existsSync()) {
        throw Exception('DesktopServices: иконка трея не найдена: $iconPath');
      }
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip(tooltip);
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _kQuickCapture, label: quickCapture),
            MenuItem.separator(),
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
        // Крестик окна сворачивает приложение в трей, выход — через меню.
        await windowManager.setPreventClose(true);
      }
      AppLogger.d('DesktopServices: подписи трея обновлены');
    } on Exception catch (e, s) {
      // Трей не критичен: приложение обязано работать и без него.
      AppLogger.e('DesktopServices: трей недоступен', e, s);
    }
  }

  /// Полный выход из приложения (в обход close-to-tray).
  static Future<void> quit() async {
    _quitting = true;
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } on Exception catch (e, s) {
      AppLogger.e('DesktopServices: не удалось закрыть окно', e, s);
    }
  }

  static Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } on Exception catch (e, s) {
      AppLogger.e('DesktopServices: не удалось показать окно', e, s);
    }
  }

  static Future<void> _hideOrClose() async {
    if (_quitting) return;
    if (!_trayReady) {
      await quit();
      return;
    }
    try {
      await windowManager.hide();
    } on Exception catch (e, s) {
      AppLogger.e('DesktopServices: не удалось скрыть окно', e, s);
    }
  }
}

/// Обработка событий трея через legacy-API tray_manager.
class _TrayListener with TrayListener {
  @override
  void onTrayIconMouseDown() => unawaited(DesktopServices._showWindow());

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case DesktopServices._kQuickCapture:
        unawaited(DesktopServices.requestQuickCapture());
      case DesktopServices._kShowWindow:
        unawaited(DesktopServices._showWindow());
      case DesktopServices._kHideWindow:
        unawaited(windowManager.hide());
      case DesktopServices._kQuit:
        unawaited(DesktopServices.quit());
    }
  }
}

/// Закрытие окна крестиком: скрываем в трей, а не завершаем процесс.
class _WindowListener extends WindowListener {
  @override
  void onWindowClose() => unawaited(DesktopServices._hideOrClose());
}
