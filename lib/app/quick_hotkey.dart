import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Глобальная комбинация быстрого ввода.
///
/// Хранится в настройках как JSON и не зависит от платформенных деталей
/// `hotkey_manager`; конвертация в [HotKey] происходит только при регистрации.
final class QuickHotkey {
  const QuickHotkey({
    required this.key,
    this.modifiers = const [HotKeyModifier.control, HotKeyModifier.alt],
  });

  /// Комбинация по умолчанию: Ctrl+Alt+B (Second Brain).
  static const QuickHotkey defaultBinding = QuickHotkey(
    key: LogicalKeyboardKey.keyB,
  );

  final LogicalKeyboardKey key;
  final List<HotKeyModifier> modifiers;

  /// Комбинация пригодна для глобальной регистрации.
  bool get isValid => modifiers.isNotEmpty && !_isModifierKey(key);

  /// Человекочитаемая подпись для настроек и подсказок.
  String get label {
    final parts = <String>[
      for (final modifier in _orderedModifiers) _modifierLabel(modifier),
      _keyLabel(key),
    ];
    return parts.join(' + ');
  }

  /// Преобразование в тип плагина. Комбинация всегда системная.
  HotKey toHotKey() => HotKey(
    key: key,
    modifiers: List<HotKeyModifier>.unmodifiable(modifiers),
    scope: HotKeyScope.system,
  );

  /// Разбирает результат записи `HotKeyRecorder`.
  static QuickHotkey? fromHotKey(HotKey hotKey) {
    try {
      final logicalKey = hotKey.logicalKey;
      final modifiers = hotKey.modifiers ?? const <HotKeyModifier>[];
      if (modifiers.isEmpty || _isModifierKey(logicalKey)) return null;
      return QuickHotkey(
        key: logicalKey,
        modifiers: List<HotKeyModifier>.unmodifiable(modifiers),
      );
    } on Object {
      return null;
    }
  }

  /// Сериализация для таблицы `app_settings`.
  String encode() => jsonEncode({
    'keyId': key.keyId,
    'keyLabel': key.keyLabel,
    'modifiers': [for (final modifier in modifiers) modifier.name],
  });

  /// Читает сохранённое значение; при повреждении возвращает null.
  static QuickHotkey? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final keyId = decoded['keyId'];
      if (keyId is! int) return null;
      final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
      if (key == null) return null;
      final rawModifiers = decoded['modifiers'];
      final modifiers = <HotKeyModifier>[];
      if (rawModifiers is List) {
        for (final item in rawModifiers) {
          if (item is! String) continue;
          HotKeyModifier? match;
          for (final modifier in HotKeyModifier.values) {
            if (modifier.name == item) {
              match = modifier;
              break;
            }
          }
          if (match != null && !modifiers.contains(match)) {
            modifiers.add(match);
          }
        }
      }
      final result = QuickHotkey(
        key: key,
        modifiers: List<HotKeyModifier>.unmodifiable(modifiers),
      );
      return result.isValid ? result : null;
    } on Object {
      return null;
    }
  }

  List<HotKeyModifier> get _orderedModifiers {
    const order = [
      HotKeyModifier.control,
      HotKeyModifier.alt,
      HotKeyModifier.shift,
      HotKeyModifier.meta,
      HotKeyModifier.capsLock,
      HotKeyModifier.fn,
    ];
    return [
      for (final modifier in order)
        if (modifiers.contains(modifier)) modifier,
      for (final modifier in modifiers)
        if (!order.contains(modifier)) modifier,
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickHotkey &&
          other.key.keyId == key.keyId &&
          _sameModifiers(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(
    key.keyId,
    Object.hashAll([...modifiers.map((modifier) => modifier.name)]..sort()),
  );

  static bool _sameModifiers(
    List<HotKeyModifier> a,
    List<HotKeyModifier> b,
  ) {
    if (a.length != b.length) return false;
    for (final modifier in a) {
      if (!b.contains(modifier)) return false;
    }
    return true;
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    final modifierKeys = {
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.capsLock,
      LogicalKeyboardKey.fn,
    };
    return modifierKeys.contains(key);
  }

  static String _modifierLabel(HotKeyModifier modifier) => switch (modifier) {
    HotKeyModifier.control => 'Ctrl',
    HotKeyModifier.alt => 'Alt',
    HotKeyModifier.shift => 'Shift',
    HotKeyModifier.meta => 'Win',
    HotKeyModifier.capsLock => 'CapsLock',
    HotKeyModifier.fn => 'Fn',
  };

  static String _keyLabel(LogicalKeyboardKey key) {
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) return label.toUpperCase();
    return key.debugName?.trim().isNotEmpty == true
        ? key.debugName!.toUpperCase()
        : 'Key ${key.keyId}';
  }
}
