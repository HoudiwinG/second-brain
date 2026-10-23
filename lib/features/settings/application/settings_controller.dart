import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/quick_hotkey.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/repositories/settings_repository.dart';

/// Маркер «аргумент не передан» для copyWith с nullable-полями.
const Object _unset = Object();

/// Снимок UI-настроек (тема и язык).
final class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.quickHotkey = QuickHotkey.defaultBinding,
  });

  /// Режим темы: системная / светлая / тёмная.
  final ThemeMode themeMode;

  /// Язык интерфейса. null — следовать системному.
  final Locale? locale;

  /// Глобальная комбинация быстрого ввода.
  final QuickHotkey quickHotkey;

  /// Копия состояния.
  ///
  /// [locale] — nullable, поэтому используется sentinel [_unset]:
  /// `copyWith()` сохраняет язык, `copyWith(locale: null)` сбрасывает его
  /// на системный (см. TD-01).
  SettingsState copyWith({
    ThemeMode? themeMode,
    Object? locale = _unset,
    QuickHotkey? quickHotkey,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    locale: identical(locale, _unset) ? this.locale : locale as Locale?,
    quickHotkey: quickHotkey ?? this.quickHotkey,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          other.themeMode == themeMode &&
          other.locale == locale &&
          other.quickHotkey == quickHotkey;

  @override
  int get hashCode => Object.hash(themeMode, locale, quickHotkey);
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
    final hotkeyRes = await repo.get(SettingsKeys.quickCaptureHotkey);
    final hotkey =
        QuickHotkey.decode(hotkeyRes.unwrap()) ?? QuickHotkey.defaultBinding;

    // Применяем сохранённую комбинацию при старте. В тестах и на не-Windows
    // платформах provider возвращает no-op. Если комбинация занята, состояние
    // должно отражать реально зарегистрированную комбинацию, иначе настройки
    // показывают одно, а срабатывает другое (R02-003).
    final apply = ref.read(quickHotkeyApplierProvider);
    var effectiveHotkey = hotkey;
    final applied = await apply(hotkey);
    if (!applied) {
      AppLogger.w(
        'SettingsController: не удалось применить сохранённую комбинацию '
        '${hotkey.label}',
      );
      if (hotkey != QuickHotkey.defaultBinding) {
        effectiveHotkey = QuickHotkey.defaultBinding;
        final fallbackApplied = await apply(effectiveHotkey);
        if (!fallbackApplied) {
          AppLogger.w(
            'SettingsController: не удалось применить резервную комбинацию '
            '${effectiveHotkey.label}',
          );
        }
        // Сохраняем фактически выбранную комбинацию, чтобы после перезапуска
        // состояние снова не расходилось с плагином.
        try {
          final saved = await repo.set(
            SettingsKeys.quickCaptureHotkey,
            effectiveHotkey.encode(),
          );
          saved.when(
            success: (_) => AppLogger.d(
              'SettingsController: сохранена резервная комбинация '
              '${effectiveHotkey.label}',
            ),
            failure: (e) => AppLogger.appError(e),
          );
        } on Object catch (e, s) {
          AppLogger.e(
            'SettingsController: не удалось сохранить резервную комбинацию',
            e,
            s,
          );
        }
      }
    }

    return SettingsState(
      themeMode: parseThemeMode(themeRaw),
      locale: parseLocale(langRaw),
      quickHotkey: effectiveHotkey,
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

  /// Регистрирует новую комбинацию быстрого ввода и сохраняет её.
  ///
  /// Сначала проверяется регистрация (комбинация может быть занята), затем
  /// настройка пишется в БД. При любой ошибке состояние откатывается.
  Future<bool> setQuickHotkey(QuickHotkey hotkey) async {
    if (!hotkey.isValid) return false;
    final current = state.value ?? const SettingsState();

    // Не выходим раньше при совпадении с state: предыдущая попытка могла
    // не зарегистрировать комбинацию, и пользователь должен иметь возможность
    // повторить применение (R02-003).
    state = AsyncData(current.copyWith(quickHotkey: hotkey));

    final apply = ref.read(quickHotkeyApplierProvider);
    final applied = await apply(hotkey);
    if (!applied) {
      // Возвращаем прежнюю комбинацию в плагин, если новая оказалась занята.
      await apply(current.quickHotkey);
      state = AsyncData(current);
      return false;
    }

    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      final res = await repo.set(
        SettingsKeys.quickCaptureHotkey,
        hotkey.encode(),
      );
      return res.when<bool>(
        success: (_) {
          AppLogger.d(
            'SettingsController: горячая клавиша сохранена (${hotkey.label})',
          );
          return true;
        },
        failure: (e) {
          AppLogger.appError(e);
          unawaited(_rollbackHotkey(current));
          return false;
        },
      );
    } on AppException catch (e) {
      AppLogger.appError(e);
      await _rollbackHotkey(current);
      return false;
    } catch (e, s) {
      AppLogger.e(
        'SettingsController: не удалось сохранить горячую клавишу',
        e,
        s,
      );
      await _rollbackHotkey(current);
      return false;
    }
  }

  Future<void> _rollbackHotkey(SettingsState previous) async {
    state = AsyncData(previous);
    await ref.read(quickHotkeyApplierProvider)(previous.quickHotkey);
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
