import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:second_brain/app/quick_hotkey.dart';

void main() {
  group('QuickHotkey', () {
    test('по умолчанию Ctrl + Alt + B', () {
      expect(QuickHotkey.defaultBinding.label, 'Ctrl + Alt + B');
      expect(QuickHotkey.defaultBinding.isValid, isTrue);
    });

    test('encode/decode сохраняет клавишу и модификаторы', () {
      const binding = QuickHotkey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );

      final decoded = QuickHotkey.decode(binding.encode());

      expect(decoded, binding);
      expect(decoded!.label, 'Ctrl + Shift + N');
      expect(decoded.key.keyId, LogicalKeyboardKey.keyN.keyId);
    });

    test('повреждённое значение не роняет настройки', () {
      expect(QuickHotkey.decode(null), isNull);
      expect(QuickHotkey.decode(''), isNull);
      expect(QuickHotkey.decode('{broken'), isNull);
      expect(QuickHotkey.decode('{"keyId": 999999999}'), isNull);
      expect(
        QuickHotkey.decode('{"keyId": ${LogicalKeyboardKey.keyB.keyId}, '
            '"modifiers": []}'),
        isNull,
      );
    });

    test('запись только модификатора не считается комбинацией', () {
      final hotKey = HotKey(
        key: LogicalKeyboardKey.controlLeft,
        modifiers: [HotKeyModifier.control],
        scope: HotKeyScope.system,
      );

      expect(QuickHotkey.fromHotKey(hotKey), isNull);
    });

    test('равенство не зависит от порядка модификаторов', () {
      const a = QuickHotkey(
        key: LogicalKeyboardKey.keyK,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      );
      const b = QuickHotkey(
        key: LogicalKeyboardKey.keyK,
        modifiers: [HotKeyModifier.alt, HotKeyModifier.control],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
