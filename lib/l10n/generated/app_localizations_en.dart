// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Second Brain';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navNotes => 'Notes';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navIdeas => 'Ideas';

  @override
  String get navFinance => 'Finance';

  @override
  String get navLearning => 'Learning';

  @override
  String get navChat => 'AI Chat';

  @override
  String get navIntegrations => 'Integrations';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get navMore => 'More';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguage => 'Interface language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageRu => 'Russian';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get emptyStateMessage =>
      'The section is empty. The business logic will appear in the next stages.';

  @override
  String get moreTitle => 'More sections';

  @override
  String get errorUnexpected => 'Unexpected error';

  @override
  String get retryAction => 'Retry';

  @override
  String get trayMenuShow => 'Show window';

  @override
  String get trayMenuHide => 'Hide window';

  @override
  String get trayMenuQuit => 'Quit';

  @override
  String get hintGlobalHotkey =>
      'Global hotkey: Ctrl+Alt+B opens the app window.';
}
