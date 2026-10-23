import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/desktop_services.dart';

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
}
