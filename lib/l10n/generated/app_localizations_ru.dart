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
      'Горячая клавиша открывает быстрый ввод из любого приложения. По умолчанию Ctrl+Alt+B.';

  @override
  String get actionAdd => 'Добавить';

  @override
  String get actionSave => 'Сохранить';

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
  String get financeEmpty => 'Операций пока нет';

  @override
  String get categoriesEmpty => 'Категорий пока нет';

  @override
  String get searchHint => 'Поиск по заметкам, задачам, идеям и финансам';

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
}
