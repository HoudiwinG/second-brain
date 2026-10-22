// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Second Brain';

  @override
  String get navDashboard => 'Дашборд';

  @override
  String get navNotes => 'Заметки';

  @override
  String get navTasks => 'Задачи';

  @override
  String get navIdeas => 'Идеи';

  @override
  String get navFinance => 'Финансы';

  @override
  String get navLearning => 'Обучение';

  @override
  String get navChat => 'AI-чат';

  @override
  String get navIntegrations => 'Интеграции';

  @override
  String get navSearch => 'Поиск';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navMore => 'Ещё';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'Системная';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguageSection => 'Язык';

  @override
  String get settingsLanguage => 'Язык интерфейса';

  @override
  String get settingsLanguageSystem => 'Системный';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageEn => 'Английский';

  @override
  String get emptyStateMessage =>
      'Раздел пуст. Бизнес-логика появится на следующих этапах.';

  @override
  String get moreTitle => 'Дополнительные разделы';

  @override
  String get errorUnexpected => 'Неожиданная ошибка';

  @override
  String get retryAction => 'Повторить';

  @override
  String get trayMenuShow => 'Показать окно';

  @override
  String get trayMenuHide => 'Скрыть окно';

  @override
  String get trayMenuQuit => 'Выход';

  @override
  String get hintGlobalHotkey =>
      'Глобальная горячая клавиша: Ctrl+Alt+B открывает окно приложения.';
}
