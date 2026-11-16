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
  String get actionAdd => 'Add';

  @override
  String get actionSave => 'Save';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionCategories => 'Categories';

  @override
  String get actionExportJson => 'Export JSON backup';

  @override
  String get actionImportJson => 'Import JSON backup';

  @override
  String get actionExportCsv => 'Export finance CSV';

  @override
  String get actionImportCsv => 'Import finance CSV';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldBody => 'Text';

  @override
  String get fieldTags => 'Tags (comma-separated)';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldPrivate => 'Do not send to LLM';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get fieldStatus => 'Status';

  @override
  String get fieldDueDate => 'Due date';

  @override
  String get fieldNoDueDate => 'No due date';

  @override
  String get fieldIdeaText => 'Idea';

  @override
  String get fieldSource => 'Source';

  @override
  String get fieldMood => 'Mood';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldNote => 'Note';

  @override
  String get fieldAccount => 'Account';

  @override
  String get fieldNewCategory => 'New category name';

  @override
  String get fieldPath => 'File path';

  @override
  String get categoryNone => 'No category';

  @override
  String get categoryParent => 'Parent category (optional)';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get statusTodo => 'To do';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusDone => 'Done';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get financeIncome => 'Income';

  @override
  String get financeExpense => 'Expense';

  @override
  String get financeBalance => 'Balance';

  @override
  String get financeTransactions => 'Transactions';

  @override
  String financeAmountWithCurrency(String label, String currency) {
    return '$label · $currency';
  }

  @override
  String get notesEmpty => 'No notes yet';

  @override
  String get tasksEmpty => 'No tasks yet';

  @override
  String get ideasEmpty => 'No ideas yet';

  @override
  String get financeEmpty => 'No transactions yet';

  @override
  String get categoriesEmpty => 'No categories yet';

  @override
  String get searchHint => 'Search notes, tasks, ideas and finance';

  @override
  String get searchNoResults => 'Nothing found';

  @override
  String get searchPrompt => 'Enter a query';

  @override
  String get searchTypeNote => 'Note';

  @override
  String get searchTypeTask => 'Task';

  @override
  String get searchTypeIdea => 'Idea';

  @override
  String get searchTypeFinance => 'Finance';

  @override
  String get privateBadge => 'Private';

  @override
  String get deleteConfirm => 'Delete this record?';

  @override
  String get dataSection => 'Data';

  @override
  String get settingsDataHint =>
      'JSON is a full backup; CSV contains finance operations.';

  @override
  String get exportSuccess => 'Backup saved';

  @override
  String get importSuccess => 'Backup imported';

  @override
  String get importWarning => 'Import replaces all local data. Continue?';

  @override
  String get errorDetails => 'Operation failed';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get dateNotSet => 'Not set';

  @override
  String get trayMenuQuickCapture => 'Quick capture';

  @override
  String get settingsHotkeySection => 'Global hotkey';

  @override
  String get settingsQuickCaptureHotkey => 'Quick capture';

  @override
  String get actionChangeHotkey => 'Change';

  @override
  String get hotkeyRecorderTitle => 'New shortcut';

  @override
  String get hotkeyRecorderHint =>
      'Press a combination with Ctrl, Alt, Shift or Win. For example, Ctrl+Alt+B.';

  @override
  String get hotkeyRecorderInvalid =>
      'A modifier plus a regular key is required.';

  @override
  String get hotkeyBusyError =>
      'The shortcut is busy or unavailable. Try another one.';

  @override
  String get fieldReminder => 'Reminder';

  @override
  String get fieldNoReminder => 'No reminder';

  @override
  String get quickCaptureTitle => 'Quick capture';

  @override
  String get quickCaptureNote => 'Note';

  @override
  String get quickCaptureTask => 'Task';

  @override
  String get quickCaptureIdea => 'Idea';

  @override
  String get quickCaptureFinance => 'Transaction';

  @override
  String get quickCaptureHint =>
      'Save with the button below. Press Esc to cancel.';

  @override
  String get quickCaptureRequired => 'Fill in the required field.';

  @override
  String get quickCaptureSaved => 'Entry saved';

  @override
  String get dashboardQuickActions => 'Quick actions';

  @override
  String get dashboardTodayTasks => 'Today\'s tasks';

  @override
  String get dashboardAll => 'All';

  @override
  String dashboardOverdueTasks(int count) {
    return 'Overdue: $count';
  }

  @override
  String get dashboardTasksEmpty => 'No tasks for today';

  @override
  String get dashboardRecentNotes => 'Recent notes';

  @override
  String get dashboardNotesEmpty => 'No notes yet';

  @override
  String get dashboardRecentIdeas => 'Recent ideas';

  @override
  String get dashboardIdeasEmpty => 'No ideas yet';

  @override
  String get dashboardFinanceMonth => 'This month\'s finance';

  @override
  String get hintGlobalHotkey =>
      'The hotkey opens quick capture from any app. Default: Ctrl+Alt+B.';

  @override
  String get settingsLlmSection => 'LLM providers';

  @override
  String get settingsLlmHint =>
      'API keys are stored in the OS secure storage and never go to the DB or logs.';

  @override
  String get actionAddProvider => 'Add provider';

  @override
  String get actionSetDefault => 'Set as default';

  @override
  String get llmProviderLabel => 'Provider';

  @override
  String get llmProviderOpenai => 'OpenAI';

  @override
  String get llmProviderOpenaiCompatible => 'OpenAI-compatible';

  @override
  String get llmProviderAnthropic => 'Anthropic';

  @override
  String get llmProviderGoogle => 'Google Gemini';

  @override
  String get llmConfigName => 'Name';

  @override
  String get llmBaseUrl => 'Base URL';

  @override
  String get llmModel => 'Model';

  @override
  String get llmApiKey => 'API key';

  @override
  String get llmApiKeyHint => 'Leave empty to keep the saved key';

  @override
  String get llmApiKeyStored => 'Key saved';

  @override
  String get llmApiKeyNotStored => 'No key';

  @override
  String get llmApiKeyDelete => 'Delete saved key';

  @override
  String get llmApiKeyDeleteHint =>
      'The saved key will be deleted when you save.';

  @override
  String get llmEmbeddingModel => 'Embedding model';

  @override
  String get llmEmbeddingModelHint =>
      'Used for RAG, separate from the chat model';

  @override
  String get validationRequired => 'Required';

  @override
  String get validationMaxTokens => 'Enter a number from 1 to 32768';

  @override
  String get validationBaseUrl =>
      'Use an http(s) URL; http is allowed only for localhost';

  @override
  String get llmMaxTokens => 'Output token limit';

  @override
  String get llmDefaultBadge => 'Default';

  @override
  String get llmNoConfigs => 'No providers configured';

  @override
  String get llmConfigSaved => 'Configuration saved';

  @override
  String get llmConfigSaveError => 'Could not save the configuration';

  @override
  String get llmConfigDeleted => 'Configuration deleted';

  @override
  String get llmConfigDeleteError => 'Could not delete the configuration';

  @override
  String get llmDefaultSet => 'Default provider updated';

  @override
  String get llmDefaultError => 'Could not change the default provider';

  @override
  String get chatTitle => 'AI Chat';

  @override
  String get chatNewThread => 'New chat';

  @override
  String get chatNoConfig =>
      'Add an LLM provider and API key in Settings first.';

  @override
  String get chatOpenSettings => 'Open settings';

  @override
  String get chatEmpty => 'Start a conversation with the assistant.';

  @override
  String get chatInputHint => 'Message…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatThreadLabel => 'Thread';

  @override
  String get chatNoThreads => 'No saved threads';

  @override
  String get chatAssistant => 'Assistant';

  @override
  String get chatYou => 'You';

  @override
  String get chatError =>
      'Could not get a response. Check the key and network.';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatApiKeyMissing =>
      'No API key saved for this provider. Add it in Settings.';

  @override
  String get chatToolSideEffect =>
      'The tool already performed an action. Check your data; retrying may create a duplicate.';

  @override
  String get chatCancelled => 'Response stopped';

  @override
  String get chatPrivateMessage => 'Excluded from context';

  @override
  String get chatMarkPrivate => 'Exclude from future context';

  @override
  String get chatUnmarkPrivate => 'Include in future context';

  @override
  String chatModelParams(String model, int tokens) {
    return '$model · $tokens tokens';
  }

  @override
  String get chatPrivacyHint =>
      'Entries marked “do not send to LLM” are excluded from context.';

  @override
  String get chatThreadDeleted => 'Thread deleted';

  @override
  String get chatDeleteThread => 'Delete thread';

  @override
  String get chatProviderMissing =>
      'The thread provider was deleted. Choose another in Settings.';

  @override
  String get chatConfigMissing => 'Configure an LLM provider first.';

  @override
  String get learningEmpty => 'No learning tracks yet';

  @override
  String get learningAddTrack => 'New track';

  @override
  String get learningEditTrack => 'Edit track';

  @override
  String get learningTrackTitle => 'Track name';

  @override
  String get learningGoal => 'Goal';

  @override
  String get learningPrivate => 'Do not send this track to LLM';

  @override
  String get learningCustomFields => 'Custom fields';

  @override
  String get learningCustomFieldsHint => 'One per line: field=value';

  @override
  String get learningRoadmap => 'Roadmap';

  @override
  String get learningNoSteps => 'No steps yet';

  @override
  String get learningAddStep => 'Add step';

  @override
  String get learningEditStep => 'Edit step';

  @override
  String get learningStepTitle => 'Step';

  @override
  String get learningStepDescription => 'Step description';

  @override
  String learningProgress(int done, int total) {
    return 'Progress: $done/$total';
  }

  @override
  String get learningStepTodo => 'To do';

  @override
  String get learningStepInProgress => 'In progress';

  @override
  String get learningStepDone => 'Done';

  @override
  String get learningSessions => 'Sessions';

  @override
  String get learningNoSessions => 'No sessions yet';

  @override
  String get learningAddSession => 'Add session';

  @override
  String get learningSessionDuration => 'Minutes';

  @override
  String learningSessionMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get learningDurationRange =>
      'Duration must be between 1 and 1440 minutes.';

  @override
  String get learningSessionNotes => 'Notes';

  @override
  String get learningSessionDate => 'Date';

  @override
  String learningTotalMinutes(int minutes) {
    return 'Total: $minutes min';
  }

  @override
  String get learningAiTrainer => 'AI trainer';

  @override
  String get learningGenerateRoadmap => 'Generate roadmap';

  @override
  String get learningSuggestMaterials => 'Suggest materials';

  @override
  String get learningCheckIn => 'Ask about progress';

  @override
  String get learningAiPrivate => 'A private track is not sent to LLM';

  @override
  String get learningAiResult => 'Trainer response';

  @override
  String get learningCheckInHint =>
      'No sessions recently. How is your learning going?';

  @override
  String get learningTrackSaved => 'Track saved';

  @override
  String get learningTrackDeleted => 'Track deleted';

  @override
  String get learningSessionSaved => 'Session added';

  @override
  String get learningSessionDeleted => 'Session deleted';

  @override
  String get learningRoadmapReplace =>
      'Replace the current roadmap with the generated one?';

  @override
  String get learningReplace => 'Replace';

  @override
  String get learningChangeStepStatus => 'Change step status';

  @override
  String get learningRoadmapEmptyGoal => 'Fill in the track goal first.';

  @override
  String get mailSection => 'Mail';

  @override
  String get mailHint =>
      'Accounts connect via OAuth 2.0 only. Tokens are stored in the OS secure storage.';

  @override
  String get mailAddAccount => 'Connect mailbox';

  @override
  String get mailNoAccounts => 'No mailboxes connected';

  @override
  String get mailProvider => 'Provider';

  @override
  String get mailEmail => 'Email';

  @override
  String get mailDisplayName => 'Mailbox name';

  @override
  String get mailClientId => 'OAuth client ID';

  @override
  String get mailClientIdHint => 'Public client ID of your OAuth application';

  @override
  String get mailClientSecret => 'OAuth client secret';

  @override
  String get mailClientSecretHint =>
      'Only if the provider requires it; stored in secure storage';

  @override
  String get mailProviderUnavailable => 'official mail read API unavailable';

  @override
  String mailRedirectHint(String uri) {
    return 'Redirect URI for the OAuth application: $uri';
  }

  @override
  String get mailConnect => 'Connect';

  @override
  String get mailConnecting => 'Waiting for OAuth…';

  @override
  String get mailAccountAdded => 'Mailbox connected';

  @override
  String get mailAccountAddError => 'Could not connect the mailbox';

  @override
  String get mailSync => 'Sync';

  @override
  String get mailSyncing => 'Syncing…';

  @override
  String mailSyncDone(int count) {
    return 'Messages loaded: $count';
  }

  @override
  String get mailSyncError => 'Could not sync mail';

  @override
  String get mailMessages => 'Messages';

  @override
  String get mailNoMessages => 'No messages yet';

  @override
  String get mailSearchHint => 'Search mail';

  @override
  String get mailPrivate => 'Do not send mail to LLM';

  @override
  String get mailReconnect => 'Re-authorize';

  @override
  String get mailDeleteAccount => 'Delete mailbox';

  @override
  String get mailAccountDeleted => 'Mailbox deleted';

  @override
  String get mailSummary => 'Summarize';

  @override
  String get mailCreateTask => 'Create task';

  @override
  String get mailTaskCreated => 'Task created';

  @override
  String get mailTaskCreateError => 'Could not create the task';

  @override
  String get mailSummarizeError => 'Could not get a summary';

  @override
  String get mailBody => 'Message body';

  @override
  String get mailFrom => 'From';

  @override
  String get mailSubject => 'Subject';

  @override
  String get mailReceived => 'Received';

  @override
  String get mailOAuthHint =>
      'A browser will open. Complete sign-in and return to the app.';

  @override
  String get mailOAuthError => 'OAuth was not completed';

  @override
  String get mailOAuthMissing => 'Fill in provider, email and client ID.';
}
