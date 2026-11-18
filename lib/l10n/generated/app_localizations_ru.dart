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
  String get actionAdd => 'Добавить';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionEdit => 'Изменить';

  @override
  String get actionRefresh => 'Обновить';

  @override
  String get actionCategories => 'Категории';

  @override
  String get actionExportJson => 'Экспорт JSON';

  @override
  String get actionImportJson => 'Импорт JSON';

  @override
  String get actionExportCsv => 'Экспорт финансов CSV';

  @override
  String get actionImportCsv => 'Импорт финансов CSV';

  @override
  String get fieldTitle => 'Заголовок';

  @override
  String get fieldBody => 'Текст';

  @override
  String get fieldTags => 'Теги (через запятую)';

  @override
  String get fieldCategory => 'Категория';

  @override
  String get fieldPrivate => 'Не отправлять в LLM';

  @override
  String get fieldDescription => 'Описание';

  @override
  String get fieldPriority => 'Приоритет';

  @override
  String get fieldStatus => 'Статус';

  @override
  String get fieldDueDate => 'Срок';

  @override
  String get fieldNoDueDate => 'Без срока';

  @override
  String get fieldIdeaText => 'Идея';

  @override
  String get fieldSource => 'Источник';

  @override
  String get fieldMood => 'Настроение';

  @override
  String get fieldAmount => 'Сумма';

  @override
  String get fieldCurrency => 'Валюта';

  @override
  String get fieldType => 'Тип';

  @override
  String get fieldDate => 'Дата';

  @override
  String get fieldNote => 'Примечание';

  @override
  String get fieldAccount => 'Счёт';

  @override
  String get fieldNewCategory => 'Название новой категории';

  @override
  String get fieldPath => 'Путь к файлу';

  @override
  String get categoryNone => 'Без категории';

  @override
  String get categoryParent => 'Родительская категория (необязательно)';

  @override
  String get priorityLow => 'Низкий';

  @override
  String get priorityNormal => 'Обычный';

  @override
  String get priorityHigh => 'Высокий';

  @override
  String get priorityUrgent => 'Срочный';

  @override
  String get statusTodo => 'К выполнению';

  @override
  String get statusInProgress => 'В работе';

  @override
  String get statusDone => 'Готово';

  @override
  String get statusCancelled => 'Отменено';

  @override
  String get financeIncome => 'Доход';

  @override
  String get financeExpense => 'Расход';

  @override
  String get financeBalance => 'Баланс';

  @override
  String get financeTransactions => 'Операции';

  @override
  String financeAmountWithCurrency(String label, String currency) {
    return '$label · $currency';
  }

  @override
  String get notesEmpty => 'Заметок пока нет';

  @override
  String get tasksEmpty => 'Задач пока нет';

  @override
  String get ideasEmpty => 'Идей пока нет';

  @override
  String get ideasSearch => 'Поиск идей';

  @override
  String get ideasSearchTitle => 'Поиск статей и изображений';

  @override
  String get ideasSearchHint => 'Тема, вопрос или запрос';

  @override
  String get ideasSearchArticles => 'Статьи';

  @override
  String get ideasSearchImages => 'Изображения';

  @override
  String get ideasSearchAction => 'Найти';

  @override
  String get ideasSearching => 'Ищем…';

  @override
  String get ideasSearchEmpty => 'Ничего не найдено';

  @override
  String get ideasSearchError => 'Не удалось выполнить поиск';

  @override
  String get ideasSaveIdea => 'В идеи';

  @override
  String get ideasSaveNote => 'В заметки';

  @override
  String get ideasSearchSaved => 'Сохранено';

  @override
  String get financeEmpty => 'Операций пока нет';

  @override
  String get categoriesEmpty => 'Категорий пока нет';

  @override
  String get searchHint =>
      'Поиск по заметкам, задачам, идеям, финансам, обучению, чату и почте';

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get searchPrompt => 'Введите запрос';

  @override
  String get searchTypeNote => 'Заметка';

  @override
  String get searchTypeTask => 'Задача';

  @override
  String get searchTypeIdea => 'Идея';

  @override
  String get searchTypeFinance => 'Финансы';

  @override
  String get searchTypeLearning => 'Обучение';

  @override
  String get searchTypeChat => 'Чат';

  @override
  String get searchTypeMail => 'Почта';

  @override
  String get searchFilters => 'Фильтры';

  @override
  String get searchAllTypes => 'Все';

  @override
  String searchResultsCount(int count) {
    return 'Найдено: $count';
  }

  @override
  String get analyticsTitle => 'Аналитика';

  @override
  String get analyticsNotes => 'Заметки';

  @override
  String get analyticsIdeas => 'Идеи';

  @override
  String get analyticsTasks => 'Задачи';

  @override
  String get analyticsTasksOpen => 'Открытые задачи';

  @override
  String get analyticsTasksDone => 'Выполнено';

  @override
  String get analyticsTasksOverdue => 'Просрочено';

  @override
  String get analyticsLearning => 'Обучение';

  @override
  String get analyticsTracks => 'Треки';

  @override
  String get analyticsSessions => 'Сессии';

  @override
  String get analyticsMinutes => 'Минуты';

  @override
  String get analyticsMail => 'Письма в кэше';

  @override
  String get analyticsFinance => 'Финансы';

  @override
  String get analyticsIncome => 'Доход';

  @override
  String get analyticsExpense => 'Расход';

  @override
  String get analyticsBalance => 'Баланс';

  @override
  String get analyticsTopExpenses => 'Топ расходов';

  @override
  String get analyticsNoExpenses => 'Расходов пока нет';

  @override
  String get analyticsTransactions => 'Операции';

  @override
  String get syncTitle => 'Синхронизация';

  @override
  String get syncHint =>
      'Локальные профили. Облачный backend пока stub: снимок живёт в памяти процесса.';

  @override
  String get syncAddProfile => 'Добавить профиль';

  @override
  String get syncProfileName => 'Название профиля';

  @override
  String get syncActive => 'Активный';

  @override
  String get syncSetActive => 'Сделать активным';

  @override
  String get syncPush => 'Отправить';

  @override
  String get syncPull => 'Получить';

  @override
  String get syncDelete => 'Удалить профиль';

  @override
  String get syncNoProfiles => 'Профилей синхронизации нет';

  @override
  String get syncSaved => 'Готово';

  @override
  String get syncError => 'Ошибка синхронизации';

  @override
  String get syncLast => 'Последняя синхронизация';

  @override
  String get syncNever => 'ещё не было';

  @override
  String get syncPullConfirm => 'Получить данные с backend?';

  @override
  String get syncPullWarning =>
      'Все локальные данные будут заменены снимком с backend. Перед заменой сохраняется локальная копия для отката.';

  @override
  String get syncUndoPull => 'Отменить последний pull';

  @override
  String get privateBadge => 'Приватно';

  @override
  String get deleteConfirm => 'Удалить запись?';

  @override
  String get dataSection => 'Данные';

  @override
  String get settingsDataHint =>
      'JSON — полный бэкап; CSV — финансовые операции.';

  @override
  String get exportSuccess => 'Бэкап сохранён';

  @override
  String get importSuccess => 'Бэкап импортирован';

  @override
  String get importWarning =>
      'Импорт заменит все локальные данные. Продолжить?';

  @override
  String get errorDetails => 'Операция не выполнена';

  @override
  String get tagsLabel => 'Теги';

  @override
  String get dateNotSet => 'Не задано';

  @override
  String get trayMenuQuickCapture => 'Быстрый ввод';

  @override
  String get settingsHotkeySection => 'Глобальная горячая клавиша';

  @override
  String get settingsQuickCaptureHotkey => 'Быстрый ввод';

  @override
  String get actionChangeHotkey => 'Изменить';

  @override
  String get hotkeyRecorderTitle => 'Новая комбинация';

  @override
  String get hotkeyRecorderHint =>
      'Нажмите комбинацию с Ctrl, Alt, Shift или Win. Например, Ctrl+Alt+B.';

  @override
  String get hotkeyRecorderInvalid =>
      'Нужна комбинация с модификатором и обычной клавишей.';

  @override
  String get hotkeyBusyError =>
      'Комбинация занята или недоступна. Попробуйте другую.';

  @override
  String get fieldReminder => 'Напоминание';

  @override
  String get fieldNoReminder => 'Без напоминания';

  @override
  String get quickCaptureTitle => 'Быстрый ввод';

  @override
  String get quickCaptureNote => 'Заметка';

  @override
  String get quickCaptureTask => 'Задача';

  @override
  String get quickCaptureIdea => 'Идея';

  @override
  String get quickCaptureFinance => 'Операция';

  @override
  String get quickCaptureHint => 'Сохраните запись кнопкой ниже. Отмена — Esc.';

  @override
  String get quickCaptureRequired => 'Заполните обязательное поле.';

  @override
  String get quickCaptureSaved => 'Запись сохранена';

  @override
  String get dashboardQuickActions => 'Быстрые действия';

  @override
  String get dashboardTodayTasks => 'Задачи на сегодня';

  @override
  String get dashboardAll => 'Все';

  @override
  String dashboardOverdueTasks(int count) {
    return 'Просрочено: $count';
  }

  @override
  String get dashboardTasksEmpty => 'На сегодня задач нет';

  @override
  String get dashboardRecentNotes => 'Последние заметки';

  @override
  String get dashboardNotesEmpty => 'Заметок пока нет';

  @override
  String get dashboardRecentIdeas => 'Последние идеи';

  @override
  String get dashboardIdeasEmpty => 'Идей пока нет';

  @override
  String get dashboardFinanceMonth => 'Финансы за месяц';

  @override
  String get hintGlobalHotkey =>
      'Горячая клавиша открывает быстрый ввод из любого приложения. По умолчанию Ctrl+Alt+B.';

  @override
  String get settingsLlmSection => 'LLM-провайдеры';

  @override
  String get settingsLlmHint =>
      'API-ключи хранятся в защищённом хранилище ОС и не попадают в БД и логи.';

  @override
  String get actionAddProvider => 'Добавить провайдера';

  @override
  String get actionSetDefault => 'Сделать основным';

  @override
  String get llmProviderLabel => 'Провайдер';

  @override
  String get llmProviderOpenai => 'OpenAI';

  @override
  String get llmProviderOpenaiCompatible => 'OpenAI-совместимый';

  @override
  String get llmProviderAnthropic => 'Anthropic';

  @override
  String get llmProviderGoogle => 'Google Gemini';

  @override
  String get llmConfigName => 'Название';

  @override
  String get llmBaseUrl => 'Base URL';

  @override
  String get llmModel => 'Модель';

  @override
  String get llmApiKey => 'API-ключ';

  @override
  String get llmApiKeyHint =>
      'Оставьте пустым, чтобы не менять сохранённый ключ';

  @override
  String get llmApiKeyStored => 'Ключ сохранён';

  @override
  String get llmApiKeyNotStored => 'Ключ не задан';

  @override
  String get llmApiKeyDelete => 'Удалить сохранённый ключ';

  @override
  String get llmApiKeyDeleteHint =>
      'Сохранённый ключ будет удалён при сохранении.';

  @override
  String get llmEmbeddingModel => 'Модель embeddings';

  @override
  String get llmEmbeddingModelHint =>
      'Используется для RAG отдельно от чат-модели';

  @override
  String get validationRequired => 'Обязательное поле';

  @override
  String get validationMaxTokens => 'Введите число от 1 до 32768';

  @override
  String get validationBaseUrl =>
      'Нужен http(s) URL; http допустим только для localhost';

  @override
  String get llmMaxTokens => 'Лимит токенов ответа';

  @override
  String get llmDefaultBadge => 'По умолчанию';

  @override
  String get llmNoConfigs => 'Провайдеры не настроены';

  @override
  String get llmConfigSaved => 'Конфигурация сохранена';

  @override
  String get llmConfigSaveError => 'Не удалось сохранить конфигурацию';

  @override
  String get llmConfigDeleted => 'Конфигурация удалена';

  @override
  String get llmConfigDeleteError => 'Не удалось удалить конфигурацию';

  @override
  String get llmDefaultSet => 'Провайдер по умолчанию обновлён';

  @override
  String get llmDefaultError => 'Не удалось изменить провайдера по умолчанию';

  @override
  String get chatTitle => 'AI-чат';

  @override
  String get chatNewThread => 'Новый чат';

  @override
  String get chatNoConfig =>
      'Сначала добавьте LLM-провайдера и API-ключ в настройках.';

  @override
  String get chatOpenSettings => 'Открыть настройки';

  @override
  String get chatEmpty => 'Начните диалог с ассистентом.';

  @override
  String get chatInputHint => 'Сообщение…';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatStop => 'Остановить';

  @override
  String get chatThreadLabel => 'Диалог';

  @override
  String get chatNoThreads => 'Нет сохранённых диалогов';

  @override
  String get chatAssistant => 'Ассистент';

  @override
  String get chatYou => 'Вы';

  @override
  String get chatError => 'Не удалось получить ответ. Проверьте ключ и сеть.';

  @override
  String get chatRetry => 'Повторить';

  @override
  String get chatApiKeyMissing =>
      'Для провайдера не сохранён API-ключ. Добавьте его в настройках.';

  @override
  String get chatToolSideEffect =>
      'Инструмент уже выполнил действие. Проверьте данные; повтор может создать дубликат.';

  @override
  String get chatCancelled => 'Ответ остановлен';

  @override
  String get chatPrivateMessage => 'Исключено из контекста';

  @override
  String get chatMarkPrivate => 'Исключить из будущего контекста';

  @override
  String get chatUnmarkPrivate => 'Включить в будущий контекст';

  @override
  String chatModelParams(String model, int tokens) {
    return '$model · $tokens токенов';
  }

  @override
  String get chatPrivacyHint =>
      'Записи с флагом «не отправлять в LLM» не попадают в контекст.';

  @override
  String get chatThreadDeleted => 'Диалог удалён';

  @override
  String get chatDeleteThread => 'Удалить диалог';

  @override
  String get chatProviderMissing =>
      'Провайдер диалога удалён. Выберите другого в настройках.';

  @override
  String get chatConfigMissing => 'Сначала настройте LLM-провайдера.';

  @override
  String get learningEmpty => 'Треков обучения пока нет';

  @override
  String get learningAddTrack => 'Новый трек';

  @override
  String get learningEditTrack => 'Редактировать трек';

  @override
  String get learningTrackTitle => 'Название трека';

  @override
  String get learningGoal => 'Цель';

  @override
  String get learningPrivate => 'Не отправлять трек в LLM';

  @override
  String get learningCustomFields => 'Дополнительные поля';

  @override
  String get learningCustomFieldsHint => 'По одному на строку: поле=значение';

  @override
  String get learningRoadmap => 'Roadmap';

  @override
  String get learningNoSteps => 'Шагов пока нет';

  @override
  String get learningAddStep => 'Добавить шаг';

  @override
  String get learningEditStep => 'Редактировать шаг';

  @override
  String get learningStepTitle => 'Шаг';

  @override
  String get learningStepDescription => 'Описание шага';

  @override
  String learningProgress(int done, int total) {
    return 'Прогресс: $done/$total';
  }

  @override
  String get learningStepTodo => 'К выполнению';

  @override
  String get learningStepInProgress => 'В работе';

  @override
  String get learningStepDone => 'Готово';

  @override
  String get learningSessions => 'Сессии';

  @override
  String get learningNoSessions => 'Сессий пока нет';

  @override
  String get learningAddSession => 'Добавить сессию';

  @override
  String get learningSessionDuration => 'Минуты';

  @override
  String learningSessionMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get learningDurationRange =>
      'Длительность должна быть от 1 до 1440 минут.';

  @override
  String get learningSessionNotes => 'Заметки';

  @override
  String get learningSessionDate => 'Дата';

  @override
  String learningTotalMinutes(int minutes) {
    return 'Всего: $minutes мин';
  }

  @override
  String get learningAiTrainer => 'AI-тренер';

  @override
  String get learningGenerateRoadmap => 'Сгенерировать roadmap';

  @override
  String get learningSuggestMaterials => 'Предложить материалы';

  @override
  String get learningCheckIn => 'Спросить о прогрессе';

  @override
  String get learningAiPrivate => 'Приватный трек не отправляется в LLM';

  @override
  String get learningAiResult => 'Ответ тренера';

  @override
  String get learningCheckInHint =>
      'Давно не было сессии. Как продвигается обучение?';

  @override
  String get learningTrackSaved => 'Трек сохранён';

  @override
  String get learningTrackDeleted => 'Трек удалён';

  @override
  String get learningSessionSaved => 'Сессия добавлена';

  @override
  String get learningSessionDeleted => 'Сессия удалена';

  @override
  String get learningRoadmapReplace =>
      'Заменить текущий roadmap сгенерированным?';

  @override
  String get learningReplace => 'Заменить';

  @override
  String get learningChangeStepStatus => 'Изменить статус шага';

  @override
  String get learningRoadmapEmptyGoal => 'Сначала заполните цель трека.';

  @override
  String get mailSection => 'Почта';

  @override
  String get mailHint =>
      'Ящики подключаются только через OAuth 2.0. Токены хранятся в защищённом хранилище ОС.';

  @override
  String get mailAddAccount => 'Подключить ящик';

  @override
  String get mailNoAccounts => 'Почтовые ящики не подключены';

  @override
  String get mailProvider => 'Провайдер';

  @override
  String get mailEmail => 'Email';

  @override
  String get mailDisplayName => 'Название ящика';

  @override
  String get mailClientId => 'OAuth client ID';

  @override
  String get mailClientIdHint => 'Публичный client ID вашего OAuth-приложения';

  @override
  String get mailClientSecret => 'OAuth client secret';

  @override
  String get mailClientSecretHint =>
      'Только если провайдер требует; хранится в secure storage';

  @override
  String get mailProviderUnavailable =>
      'официальный API чтения писем недоступен';

  @override
  String mailRedirectHint(String uri) {
    return 'Redirect URI для OAuth-приложения: $uri';
  }

  @override
  String get mailConnect => 'Подключить';

  @override
  String get mailConnecting => 'Ожидание OAuth…';

  @override
  String get mailAccountAdded => 'Ящик подключён';

  @override
  String get mailAccountAddError => 'Не удалось подключить ящик';

  @override
  String get mailSync => 'Синхронизировать';

  @override
  String get mailSyncing => 'Синхронизация…';

  @override
  String mailSyncDone(int count) {
    return 'Загружено писем: $count';
  }

  @override
  String get mailSyncError => 'Не удалось синхронизировать почту';

  @override
  String get mailMessages => 'Письма';

  @override
  String get mailNoMessages => 'Писем пока нет';

  @override
  String get mailSearchHint => 'Поиск по почте';

  @override
  String get mailPrivate => 'Не отправлять письма в LLM';

  @override
  String get mailReconnect => 'Авторизоваться заново';

  @override
  String get mailDeleteAccount => 'Удалить ящик';

  @override
  String get mailAccountDeleted => 'Ящик удалён';

  @override
  String get mailSummary => 'Суммаризировать';

  @override
  String get mailCreateTask => 'Создать задачу';

  @override
  String get mailTaskCreated => 'Задача создана';

  @override
  String get mailTaskCreateError => 'Не удалось создать задачу';

  @override
  String get mailSummarizeError => 'Не удалось получить резюме';

  @override
  String get mailBody => 'Текст письма';

  @override
  String get mailFrom => 'От';

  @override
  String get mailSubject => 'Тема';

  @override
  String get mailNoSubject => '(без темы)';

  @override
  String get mailReceived => 'Получено';

  @override
  String get mailOAuthHint =>
      'Откроется браузер. Завершите вход и вернитесь в приложение.';

  @override
  String get mailOAuthError => 'OAuth не завершён';

  @override
  String get mailOAuthMissing => 'Заполните провайдера, email и client ID.';
}
