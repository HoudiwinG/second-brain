import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Second Brain'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navIdeas.
  ///
  /// In en, this message translates to:
  /// **'Ideas'**
  String get navIdeas;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get navLearning;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get navChat;

  /// No description provided for @navIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get navIntegrations;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get settingsLanguageRu;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @emptyStateMessage.
  ///
  /// In en, this message translates to:
  /// **'The section is empty. The business logic will appear in the next stages.'**
  String get emptyStateMessage;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More sections'**
  String get moreTitle;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get errorUnexpected;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @trayMenuShow.
  ///
  /// In en, this message translates to:
  /// **'Show window'**
  String get trayMenuShow;

  /// No description provided for @trayMenuHide.
  ///
  /// In en, this message translates to:
  /// **'Hide window'**
  String get trayMenuHide;

  /// No description provided for @trayMenuQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayMenuQuit;

  /// No description provided for @hintGlobalHotkey.
  ///
  /// In en, this message translates to:
  /// **'The hotkey opens quick capture from any app. Default: Ctrl+Alt+B.'**
  String get hintGlobalHotkey;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get actionCategories;

  /// No description provided for @actionExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON backup'**
  String get actionExportJson;

  /// No description provided for @actionImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON backup'**
  String get actionImportJson;

  /// No description provided for @actionExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export finance CSV'**
  String get actionExportCsv;

  /// No description provided for @actionImportCsv.
  ///
  /// In en, this message translates to:
  /// **'Import finance CSV'**
  String get actionImportCsv;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldBody.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get fieldBody;

  /// No description provided for @fieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma-separated)'**
  String get fieldTags;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldPrivate.
  ///
  /// In en, this message translates to:
  /// **'Do not send to LLM'**
  String get fieldPrivate;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get fieldPriority;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @fieldDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get fieldDueDate;

  /// No description provided for @fieldNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get fieldNoDueDate;

  /// No description provided for @fieldIdeaText.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get fieldIdeaText;

  /// No description provided for @fieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get fieldSource;

  /// No description provided for @fieldMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get fieldMood;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldCurrency;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get fieldNote;

  /// No description provided for @fieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fieldAccount;

  /// No description provided for @fieldNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category name'**
  String get fieldNewCategory;

  /// No description provided for @fieldPath.
  ///
  /// In en, this message translates to:
  /// **'File path'**
  String get fieldPath;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get categoryNone;

  /// No description provided for @categoryParent.
  ///
  /// In en, this message translates to:
  /// **'Parent category (optional)'**
  String get categoryParent;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @statusTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get statusTodo;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @financeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get financeIncome;

  /// No description provided for @financeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get financeExpense;

  /// No description provided for @financeBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get financeBalance;

  /// No description provided for @financeTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get financeTransactions;

  /// No description provided for @financeAmountWithCurrency.
  ///
  /// In en, this message translates to:
  /// **'{label} · {currency}'**
  String financeAmountWithCurrency(String label, String currency);

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmpty;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get tasksEmpty;

  /// No description provided for @ideasEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ideas yet'**
  String get ideasEmpty;

  /// No description provided for @financeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get financeEmpty;

  /// No description provided for @categoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get categoriesEmpty;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes, tasks, ideas and finance'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get searchNoResults;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a query'**
  String get searchPrompt;

  /// No description provided for @searchTypeNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get searchTypeNote;

  /// No description provided for @searchTypeTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get searchTypeTask;

  /// No description provided for @searchTypeIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get searchTypeIdea;

  /// No description provided for @searchTypeFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get searchTypeFinance;

  /// No description provided for @privateBadge.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateBadge;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get deleteConfirm;

  /// No description provided for @dataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataSection;

  /// No description provided for @settingsDataHint.
  ///
  /// In en, this message translates to:
  /// **'JSON is a full backup; CSV contains finance operations.'**
  String get settingsDataHint;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup imported'**
  String get importSuccess;

  /// No description provided for @importWarning.
  ///
  /// In en, this message translates to:
  /// **'Import replaces all local data. Continue?'**
  String get importWarning;

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get errorDetails;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// No description provided for @dateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get dateNotSet;

  /// No description provided for @trayMenuQuickCapture.
  ///
  /// In en, this message translates to:
  /// **'Quick capture'**
  String get trayMenuQuickCapture;

  /// No description provided for @settingsHotkeySection.
  ///
  /// In en, this message translates to:
  /// **'Global hotkey'**
  String get settingsHotkeySection;

  /// No description provided for @settingsQuickCaptureHotkey.
  ///
  /// In en, this message translates to:
  /// **'Quick capture'**
  String get settingsQuickCaptureHotkey;

  /// No description provided for @actionChangeHotkey.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChangeHotkey;

  /// No description provided for @hotkeyRecorderTitle.
  ///
  /// In en, this message translates to:
  /// **'New shortcut'**
  String get hotkeyRecorderTitle;

  /// No description provided for @hotkeyRecorderHint.
  ///
  /// In en, this message translates to:
  /// **'Press a combination with Ctrl, Alt, Shift or Win. For example, Ctrl+Alt+B.'**
  String get hotkeyRecorderHint;

  /// No description provided for @hotkeyRecorderInvalid.
  ///
  /// In en, this message translates to:
  /// **'A modifier plus a regular key is required.'**
  String get hotkeyRecorderInvalid;

  /// No description provided for @hotkeyBusyError.
  ///
  /// In en, this message translates to:
  /// **'The shortcut is busy or unavailable. Try another one.'**
  String get hotkeyBusyError;

  /// No description provided for @fieldReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get fieldReminder;

  /// No description provided for @fieldNoReminder.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get fieldNoReminder;

  /// No description provided for @quickCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick capture'**
  String get quickCaptureTitle;

  /// No description provided for @quickCaptureNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get quickCaptureNote;

  /// No description provided for @quickCaptureTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get quickCaptureTask;

  /// No description provided for @quickCaptureIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get quickCaptureIdea;

  /// No description provided for @quickCaptureFinance.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get quickCaptureFinance;

  /// No description provided for @quickCaptureHint.
  ///
  /// In en, this message translates to:
  /// **'Save with the button below. Press Esc to cancel.'**
  String get quickCaptureHint;

  /// No description provided for @quickCaptureRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in the required field.'**
  String get quickCaptureRequired;

  /// No description provided for @quickCaptureSaved.
  ///
  /// In en, this message translates to:
  /// **'Entry saved'**
  String get quickCaptureSaved;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardTodayTasks.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tasks'**
  String get dashboardTodayTasks;

  /// No description provided for @dashboardAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dashboardAll;

  /// No description provided for @dashboardOverdueTasks.
  ///
  /// In en, this message translates to:
  /// **'Overdue: {count}'**
  String dashboardOverdueTasks(int count);

  /// No description provided for @dashboardTasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks for today'**
  String get dashboardTasksEmpty;

  /// No description provided for @dashboardRecentNotes.
  ///
  /// In en, this message translates to:
  /// **'Recent notes'**
  String get dashboardRecentNotes;

  /// No description provided for @dashboardNotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get dashboardNotesEmpty;

  /// No description provided for @dashboardRecentIdeas.
  ///
  /// In en, this message translates to:
  /// **'Recent ideas'**
  String get dashboardRecentIdeas;

  /// No description provided for @dashboardIdeasEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ideas yet'**
  String get dashboardIdeasEmpty;

  /// No description provided for @dashboardFinanceMonth.
  ///
  /// In en, this message translates to:
  /// **'This month\'s finance'**
  String get dashboardFinanceMonth;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
