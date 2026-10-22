import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/error/app_exception.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';
import 'package:second_brain/features/settings/application/settings_controller.dart';

/// Репозиторий с управляемой ошибкой записи (R00-014).
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.failWrites = false});

  final bool failWrites;

  @override
  Future<Result<String?>> get(String key) async => const Result.success(null);

  @override
  Future<Result<String>> getOrDefault(String key, String fallback) async =>
      Result.success(fallback);

  @override
  Future<Result<void>> set(String key, String value) async {
    if (failWrites) {
      return const Result.failure(DataException('тест: запись запрещена'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> remove(String key) async =>
      const Result<void>.success(null);

  @override
  Future<int> count() async => 0;
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
  });
}
