import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/settings/application/settings_controller.dart';
import 'package:second_brain/core/secrets/in_memory_secret_store.dart';
import 'package:second_brain/core/secrets/secret_store.dart';
import 'package:second_brain/data/repositories/settings_repository.dart';
import 'package:second_brain/data/db/app_database.dart';

import 'helpers/in_memory_db.dart';

void main() {
  group('SettingsRepository (in-memory AppDatabase)', () {
    late AppDatabase db;

    setUp(() {
      db = InMemoryDbFactory.open();
    });

    tearDown(() {
      db.close();
    });

    test('чтение отсутствующей настройки возвращает null', () async {
      final repo = SettingsRepository(db);
      final res = await repo.get(SettingsKeys.themeMode);

      expect(res.when(success: (v) => v, failure: (e) => 'error:$e'), isNull);
    });

    test('set/getOrDefault roundtrip сохраняет значение', () async {
      final repo = SettingsRepository(db);

      final setRes = await repo.set(SettingsKeys.themeMode, 'dark');
      setRes.when(
        success: (_) {},
        failure: (e) => fail('set не должен падать: $e'),
      );

      final res = await repo.getOrDefault(SettingsKeys.themeMode, 'system');
      expect(res.unwrap(), 'dark');
    });

    test('getOrDefault возвращает fallback, если настройки нет', () async {
      final repo = SettingsRepository(db);

      final res = await repo.getOrDefault(SettingsKeys.themeMode, 'system');
      expect(res.unwrap(), 'system');
    });

    test('повторный set перезаписывает значение (upsert)', () async {
      final repo = SettingsRepository(db);

      await repo.set(SettingsKeys.themeMode, 'dark');
      await repo.set(SettingsKeys.themeMode, 'light');

      final res = await repo.get(SettingsKeys.themeMode);
      expect(res.unwrap(), 'light');
    });

    test('значения лежат в двух независимых ключах', () async {
      final repo = SettingsRepository(db);

      await repo.set(SettingsKeys.themeMode, 'dark');
      await repo.set(SettingsKeys.language, 'ru');

      expect((await repo.get(SettingsKeys.themeMode)).unwrap(), 'dark');
      expect((await repo.get(SettingsKeys.language)).unwrap(), 'ru');
      expect(await repo.count(), 2);
    });

    test('remove удаляет запись', () async {
      final repo = SettingsRepository(db);
      await repo.set(SettingsKeys.themeMode, 'dark');
      await repo.remove(SettingsKeys.themeMode);

      expect((await repo.get(SettingsKeys.themeMode)).unwrap(), isNull);
      expect(await repo.count(), 0);
    });
  });

  group('SettingsController: чистые парсеры', () {
    test('parseThemeMode', () {
      expect(SettingsController.parseThemeMode('light'), ThemeMode.light);
      expect(SettingsController.parseThemeMode('dark'), ThemeMode.dark);
      expect(SettingsController.parseThemeMode('system'), ThemeMode.system);
      expect(SettingsController.parseThemeMode('unknown'), ThemeMode.system);
    });

    test('parseLocale', () {
      expect(SettingsController.parseLocale('ru'), const Locale('ru'));
      expect(SettingsController.parseLocale('en'), const Locale('en'));
      expect(
        SettingsController.parseLocale(SettingsController.localeSystem),
        isNull,
      );
      expect(SettingsController.parseLocale('xx'), isNull);
    });
  });

  group('SettingsState.copyWith', () {
    test('locale сбрасывается в null (системный язык)', () {
      const state = SettingsState(locale: Locale('ru'));

      // Без аргументов — язык сохраняется.
      expect(state.copyWith().locale, const Locale('ru'));

      // Явный null должен сбросить язык, а не проигнорироваться (TD-01).
      expect(state.copyWith(locale: null).locale, isNull);

      // Смена темы не трогает язык.
      expect(
        state.copyWith(themeMode: ThemeMode.dark).locale,
        const Locale('ru'),
      );
    });

    test('value equality: одинаковые состояния равны', () {
      const a = SettingsState(themeMode: ThemeMode.dark, locale: Locale('en'));
      const b = SettingsState(themeMode: ThemeMode.dark, locale: Locale('en'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('InMemorySecretStore (SecretStore контракт)', () {
    test('write/read/delete/clear', () async {
      final SecretStore store = InMemorySecretStore();

      await store.write('api_key', 'sk-test');
      expect((await store.read('api_key')).unwrap(), 'sk-test');

      await store.delete('api_key');
      expect((await store.read('api_key')).unwrap(), isNull);

      await store.write('k1', 'v1');
      await store.write('k2', 'v2');
      await store.clear();
      expect((await store.read('k1')).unwrap(), isNull);
      expect((await store.read('k2')).unwrap(), isNull);
    });
  });
}
