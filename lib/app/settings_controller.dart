import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../data/repositories/settings_repository.dart';
import 'di.dart';

/// Снимок UI-настроек (тема и язык).
final class SettingsState {
  const SettingsState({this.themeMode = ThemeMode.system, this.locale});

  /// Режим темы: системная / светлая / тёмная.
  final ThemeMode themeMode;

  /// Язык интерфейса. null — следовать системному.
  final Locale? locale;

  SettingsState copyWith({ThemeMode? themeMode, Locale? locale}) => SettingsState(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );
}

/// Контроллер UI-настроек: тема и язык, персистентность в Drift.
///
/// Читается через settingsControllerProvider; виджет [MaterialApp]
/// применяет тему и локаль напрямую из состояния.
class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);

    final themeRes = await repo.getOrDefault(SettingsKeys.themeMode, ThemeMode.system.name);
    final themeRaw = themeRes.unwrap();
    final langRes = await repo.getOrDefault(SettingsKeys.language, localeSystem);
    final langRaw = langRes.unwrap();

    return SettingsState(
      themeMode: parseThemeMode(themeRaw),
      locale: parseLocale(langRaw),
    );
  }

  /// Устанавливает тему и сохраняет её в БД.
  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(themeMode: mode));

    final repo = await ref.read(settingsRepositoryProvider.future);
    final res = await repo.set(SettingsKeys.themeMode, mode.name);
    res.when(
      success: (_) => AppLogger.d('SettingsController: тема сохранена (${mode.name})'),
      failure: (e) {
        AppLogger.appError(e);
        state = AsyncData((state.value ?? current).copyWith(themeMode: current.themeMode));
      },
    );
  }

  /// Устанавливает язык интерфейса и сохраняет выбор в БД.
  Future<void> setLocale(Locale? locale) async {
    final code = locale?.languageCode ?? localeSystem;
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(locale: locale));

    final repo = await ref.read(settingsRepositoryProvider.future);
    final res = await repo.set(SettingsKeys.language, code);
    res.when(
      success: (_) => AppLogger.d('SettingsController: язык сохранён ($code)'),
      failure: (e) {
        AppLogger.appError(e);
        state = AsyncData((state.value ?? current).copyWith(locale: current.locale));
      },
    );
  }

  /// Парсит сохранённый режим темы.
  static ThemeMode parseThemeMode(String raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Парсит сохранённую локаль; 'system' → null.
  static Locale? parseLocale(String raw) => switch (raw) {
        'ru' => const Locale('ru'),
        'en' => const Locale('en'),
        _ => null,
      };

  /// Маркер «системная локаль» в хранилище.
  static const String localeSystem = 'system';
}

/// Провайдер контроллера настроек.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(SettingsController.new);
