import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'package:second_brain/app/di.dart';
import 'package:second_brain/app/quick_hotkey.dart';
import 'package:second_brain/core/error/app_exception.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';
import 'package:second_brain/features/settings/application/settings_controller.dart';

/// Репозиторий с управляемой ошибкой записи (R00-014).
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    this.failWrites = false,
    Map<String, String>? initial,
  }) : _values = {...?initial};

  final bool failWrites;
  final Map<String, String> _values;
  final List<String> writes = [];

  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<Result<String?>> get(String key) async => Result.success(_values[key]);

  @override
  Future<Result<String>> getOrDefault(String key, String fallback) async =>
      Result.success(_values[key] ?? fallback);

  @override
  Future<Result<void>> set(String key, String value) async {
    if (failWrites) {
      return const Result.failure(DataException('тест: запись запрещена'));
    }
    _values[key] = value;
    writes.add(key);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> remove(String key) async {
    _values.remove(key);
    return const Result<void>.success(null);
  }

  @override
  Future<int> count() async => _values.length;
}

void main() {
  group('SettingsController: результат сохранения (R00-014)', () {
    test('успешное сохранение темы возвращает true', () async {
      final container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWith(
            (ref) async => _FakeSettingsRepository(),
          ),
        ],
      );
      await container.read(settingsControllerProvider.future);
      final controller = container.read(settingsControllerProvider.notifier);

      final saved = await controller.setThemeMode(ThemeMode.dark);

      expect(saved, isTrue);
      expect(
        container.read(settingsControllerProvider).value?.themeMode,
        ThemeMode.dark,
      );
    });

    test(
      'ошибка сохранения темы откатывает состояние и возвращает false',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            settingsRepositoryProvider.overrideWith(
              (ref) async => _FakeSettingsRepository(failWrites: true),
            ),
          ],
        );
        await container.read(settingsControllerProvider.future);
        final controller = container.read(settingsControllerProvider.notifier);

        final saved = await controller.setThemeMode(ThemeMode.dark);

        expect(saved, isFalse);
        expect(
          container.read(settingsControllerProvider).value?.themeMode,
          ThemeMode.system,
        );
      },
    );

    test(
      'ошибка сохранения языка откатывает состояние и возвращает false',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            settingsRepositoryProvider.overrideWith(
              (ref) async => _FakeSettingsRepository(failWrites: true),
            ),
          ],
        );
        await container.read(settingsControllerProvider.future);
        final controller = container.read(settingsControllerProvider.notifier);

        final saved = await controller.setLocale(const Locale('ru'));

        expect(saved, isFalse);
        expect(
          container.read(settingsControllerProvider).value?.locale,
          isNull,
        );
      },
    );

    test('startup: занятая сохранённая комбинация откатывается на default (R02-003)', () async {
      const saved = QuickHotkey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      final repo = _FakeSettingsRepository(
        initial: {SettingsKeys.quickCaptureHotkey: saved.encode()},
      );
      final applied = <QuickHotkey>[];
      final container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => repo),
          quickHotkeyApplierProvider.overrideWithValue((hotkey) async {
            applied.add(hotkey);
            return hotkey == QuickHotkey.defaultBinding;
          }),
        ],
      );

      final state = await container.read(settingsControllerProvider.future);

      expect(state.quickHotkey, QuickHotkey.defaultBinding);
      expect(applied, [saved, QuickHotkey.defaultBinding]);
      expect(repo.writes, contains(SettingsKeys.quickCaptureHotkey));
      expect(
        repo.values[SettingsKeys.quickCaptureHotkey],
        QuickHotkey.defaultBinding.encode(),
      );
    });

    test('setQuickHotkey регистрирует и сохраняет комбинацию', () async {
      final applied = <QuickHotkey>[];
      final container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWith(
            (ref) async => _FakeSettingsRepository(),
          ),
          quickHotkeyApplierProvider.overrideWithValue((hotkey) async {
            applied.add(hotkey);
            return true;
          }),
        ],
      );
      await container.read(settingsControllerProvider.future);
      applied.clear();
      final controller = container.read(settingsControllerProvider.notifier);

      const binding = QuickHotkey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      final saved = await controller.setQuickHotkey(binding);

      expect(saved, isTrue);
      expect(
        container.read(settingsControllerProvider).value?.quickHotkey,
        binding,
      );
      expect(applied, contains(binding));
    });

    test('занятая комбинация не меняет настройку', () async {
      final container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWith(
            (ref) async => _FakeSettingsRepository(),
          ),
          quickHotkeyApplierProvider.overrideWithValue((_) async => false),
        ],
      );
      await container.read(settingsControllerProvider.future);
      final controller = container.read(settingsControllerProvider.notifier);

      const binding = QuickHotkey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.control],
      );
      final saved = await controller.setQuickHotkey(binding);

      expect(saved, isFalse);
      expect(
        container.read(settingsControllerProvider).value?.quickHotkey,
        QuickHotkey.defaultBinding,
      );
    });
  });
}
