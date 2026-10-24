import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:second_brain/app/desktop_services.dart';
import 'package:second_brain/app/quick_hotkey.dart';

void main() {
  group('DesktopServices: путь к иконке трея (R02-001)', () {
    test('Windows: абсолютный путь внутри data/flutter_assets', () {
      final executable = [
        Directory.current.path,
        'build',
        'second_brain.exe',
      ].join(Platform.pathSeparator);

      final path = DesktopServices.trayIconPath(
        platform: TargetPlatform.windows,
        executablePath: executable,
      );

      final expected = [
        Directory(executable).parent.path,
        'data',
        'flutter_assets',
        'assets',
        'tray_icon.ico',
      ].join(Platform.pathSeparator);
      expect(path, expected);
      expect(File(path).isAbsolute, isTrue);
    });

    test('Windows без явного пути использует resolvedExecutable', () {
      final path = DesktopServices.trayIconPath(
        platform: TargetPlatform.windows,
      );

      expect(File(path).isAbsolute, isTrue);
      expect(
        path,
        endsWith(
          [
            'data',
            'flutter_assets',
            'assets',
            'tray_icon.ico',
          ].join(Platform.pathSeparator),
        ),
      );
    });

    test('не-Windows использует PNG-ассет', () {
      expect(
        DesktopServices.trayIconPath(
          platform: TargetPlatform.linux,
          executablePath: '/opt/second_brain/second_brain',
        ),
        'assets/tray_icon.png',
      );
    });
  });

  group('DesktopServices: занятая комбинация (R02-009)', () {
    const busy = QuickHotkey(
      key: LogicalKeyboardKey.keyN,
      modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
    );

    setUp(DesktopServices.resetHotkeyForTesting);
    tearDown(DesktopServices.resetHotkeyForTesting);

    test(
      'ошибка register возвращает false и восстанавливает прежнюю',
      () async {
        final registered = <QuickHotkey>[];
        Future<void> register(QuickHotkey binding) async {
          if (binding == busy) {
            throw PlatformException(
              code: 'hotkey_busy',
              message: 'RegisterHotKey failed',
            );
          }
          registered.add(binding);
        }

        Future<void> unregisterAll() async {}

        final first = await DesktopServices.applyHotkeyBinding(
          QuickHotkey.defaultBinding,
          register: register,
          unregisterAll: unregisterAll,
        );
        expect(first, isTrue);

        final second = await DesktopServices.applyHotkeyBinding(
          busy,
          register: register,
          unregisterAll: unregisterAll,
        );

        expect(second, isFalse);
        expect(registered, [
          QuickHotkey.defaultBinding,
          QuickHotkey.defaultBinding,
        ]);
      },
    );

    test('ошибка без прежней комбинации возвращает false', () async {
      Future<void> register(QuickHotkey binding) async {
        throw PlatformException(code: 'hotkey_busy');
      }

      final applied = await DesktopServices.applyHotkeyBinding(
        busy,
        register: register,
        unregisterAll: () async {},
      );

      expect(applied, isFalse);
    });
  });

  group('Вендорный патч hotkey_manager_windows (R02-009/ADR-017)', () {
    test('RegisterHotKey проверяется и возвращает hotkey_busy', () {
      final source = File(
        [
          'third_party',
          'hotkey_manager_windows',
          'windows',
          'hotkey_manager_windows_plugin.cpp',
        ].join(Platform.pathSeparator),
      ).readAsStringSync();

      expect(source, contains('if (!::RegisterHotKey('));
      expect(source, contains('"hotkey_busy"'));
      final errorIndex = source.indexOf('result->Error');
      final insertIndex = source.indexOf('hotkey_id_map_.insert');
      expect(errorIndex, isNonNegative);
      expect(insertIndex, isNonNegative);
      expect(errorIndex, lessThan(insertIndex));
    });

    test('pubspec подключает патч через dependency_overrides', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('dependency_overrides:'));
      expect(pubspec, contains('hotkey_manager_windows:'));
      expect(pubspec, contains('path: third_party/hotkey_manager_windows'));
      expect(
        pubspec.indexOf('hotkey_manager_windows:'),
        greaterThan(pubspec.indexOf('dependency_overrides:')),
      );
    });
  });
}
