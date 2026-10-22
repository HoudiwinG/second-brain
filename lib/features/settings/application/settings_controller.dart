import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/repositories/settings_repository.dart';

/// Маркер «аргумент не передан» для copyWith с nullable-полями.
const Object _unset = Object();

/// Снимок UI-настроек (тема и язык).
final class SettingsState {
  const SettingsState({this.themeMode = ThemeMode.system, this.locale});

  /// Режим темы: системная / светлая / тёмная.
  final ThemeMode themeMode;

  /// Язык интерфейса. null — следовать системному.
  final Locale? locale;

  /// Копия состояния.
  ///
  /// [locale] — nullable, поэтому используется sentinel [_unset]:
  /// `copyWith()` сохраняет язык, `copyWith(locale: null)` сбрасывает его
  /// на системный (см. TD-01).
  SettingsState copyWith({ThemeMode? themeMode, Object? locale = _unset}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        locale: identical(locale, _unset) ? this.locale : locale as Locale?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          other.themeMode == themeMode &&
          other.locale == locale;

  @override
  int get hashCode => Object.hash(themeMode, locale);
}

/// Контроллер UI-настроек: тема и язык, персистентность в Drift.
///
/// Читается через settingsControllerProvider; виджет [MaterialApp]
/// применяет тему и локаль напрямую из состояния.
class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);

    final themeRes = await repo.getOrDefault(
      SettingsKeys.themeMode,
      ThemeMode.system.name,
    );
    final themeRaw = themeRes.unwrap();
    final langRes = await repo.getOrDefault(
      SettingsKeys.language,
      localeSystem,
    );
    final langRaw = langRes.unwrap();

    return SettingsState(
      themeMode: parseThemeMode(themeRaw),
      locale: parseLocale(langRaw),
    );
  }

  /// Устанавливает тему и сохраняет её в БД.
  ///
  /// Сначала применяет тему оптимистично, затем сохраняет. Любая ошибка
  /// (включая недоступную БД) откатывает UI и логируется — исключение не
  /// должно всплывать из обработчика нажатия (R00-009).
  ///
  /// Возвращает `true`, если настройка сохранена; `false` — если пришлось
  /// откатить состояние (R00-014: UI показывает локализованную ошибку).
  Future<bool> setThemeMode(ThemeMode mode) async {
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(themeMode: mode));

    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      final res = await repo.set(SettingsKeys.themeMode, mode.name);
      return res.when<bool>(
        success: (_) {
          AppLogger.d('SettingsController: тема сохранена (${mode.name})');
          return true;
        },
        failure: (e) {
          AppLogger.appError(e);
          state = AsyncData(
            (state.value ?? current).copyWith(themeMode: current.themeMode),
          );
          return false;
        },
      );
    } on AppException catch (e) {
      AppLogger.appError(e);
      state = AsyncData(
        (state.value ?? current).copyWith(themeMode: current.themeMode),
      );
      return false;
    } catch (e, s) {
      AppLogger.e('SettingsController: не удалось сохранить тему', e, s);
      state = AsyncData(
        (state.value ?? current).copyWith(themeMode: current.themeMode),
      );
      return false;
    }
  }

  /// Устанавливает язык интерфейса и сохраняет выбор в БД.
  ///
  /// null — системный язык. Ошибки откатывают выбор, не покидая контроллер
  /// (R00-009). Возвращает `true` при успешном сохранении, иначе `false`.
  Future<bool> setLocale(Locale? locale) async {
    final code = locale?.languageCode ?? localeSystem;
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(locale: locale));

    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      final res = await repo.set(SettingsKeys.language, code);
      return res.when<bool>(
        success: (_) {
          AppLogger.d('SettingsController: язык сохранён ($code)');
          return true;
        },
        failure: (e) {
          AppLogger.appError(e);
          state = AsyncData(
            (state.value ?? current).copyWith(locale: current.locale),
          );
          return false;
        },
      );
    } on AppException catch (e) {
      AppLogger.appError(e);
      state = AsyncData(
        (state.value ?? current).copyWith(locale: current.locale),
      );
      return false;
    } catch (e, s) {
      AppLogger.e('SettingsController: не удалось сохранить язык', e, s);
      state = AsyncData(
        (state.value ?? current).copyWith(locale: current.locale),
      );
      return false;
    }
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
    AsyncNotifierProvider<SettingsController, SettingsState>(
      SettingsController.new,
    );
