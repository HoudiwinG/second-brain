import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('installer и CI содержат обязательные шаги', () {
    final iss = File('installer/second_brain.iss').readAsStringSync();
    final ci = File('.github/workflows/ci.yml').readAsStringSync();

    expect(iss, contains('PrivilegesRequired=lowest'));
    expect(iss, contains('vc_redist.x64.exe'));
    expect(iss, contains('OutputBaseFilename=SecondBrain-'));
    expect(ci, contains('flutter build windows --release'));
    expect(ci, contains('build_installer.ps1'));
    expect(ci, contains('upload-artifact@v4'));
    expect(ci, contains('second-brain-windows'));
  });
}
