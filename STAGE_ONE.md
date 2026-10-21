# ЭТАП 0 — КАРКАС ПРОЕКТА (Flutter, Windows-first)

Ты продолжаешь проект «Second Brain + AI Assistant» по основному промпту.
Сейчас выполняется ТОЛЬКО Этап 0. Не выходи за его рамки: бизнес-логики
заметок/задач/LLM/интеграций ещё нет.

## ЗАДАЧИ ЭТАПА 0
1. Создать Flutter-проект (Windows + Android + iOS), включить desktop.
2. Структура папок feature-first + clean architecture:
   lib/
     app/            (app-роутер, темы, локализация, DI)
     core/           (api_client, secure_storage, crypto_service, errors,
                      result, logging, feature_flags)
     data/           (drift db, миграции, репозитории-заготовки)
     features/
       dashboard/    (пустой экран)
       notes/        (пустой экран)
       tasks/        (пустой экран)
       ideas/        (пустой экран)
       finance/      (пустой экран)
       learning/     (пустой экран)
       chat/         (пустой экран)
       integrations/ (пустой экран)
       search/       (пустой экран)
       settings/     (пустой экран)
     l10n/
3. Зависимости: flutter_riverpod, go_router, drift, sqlite3_flutter_libs,
   flutter_secure_storage, flutter_localizations, intl, logger,
   window_manager, tray_manager, hotkey_manager, flutter_lints.
   Обоснование — в decisions.md.
4. Локализация RU/EN (ARB), переключатель языка в настройках.
5. Тёмная/светлая тема, переключатель.
6. Drift DB с первой пустой миграцией и схемой (только таблица Settings —
   чтобы проверить миграции). Сгенерировать код.
7. SecureStorage-обёртка с интерфейсом SecretStore.
8. DI через Riverpod: провайдеры для БД, настроек, роутера.
9. Роутер с заглушками экранов и нижней/боковой навигацией.
10. Логирование (logger) + заглушка под crash-reporter.
11. Тесты: один юнит-тест на настройки, один widget-тест роутинга,
    интеграционный тест миграции БД (in-memory).
12. Windows: иконка в трее и глобальная горячая клавиша (открыть окно).
13. CI: скрипт/конфиг, который гоняет flutter analyze + flutter test.
14. Документация:
    - /docs/INDEX.md
    - /docs/context.md (текущий этап = 0, статус)
    - /docs/decisions.md (записи: выбор Riverpod, Drift, secure storage,
      tray/hotkey, структура папок, локализация)
    - /docs/decisions.template.md
    - /docs/stages/stage-00.md — заполнить по завершении этапа
15. Проверить: flutter pub get, flutter analyze (0 issues),
    flutter test (зелёные), flutter build windows (успешная сборка).

## КРИТЕРИИ ПРИЁМКИ ЭТАПА 0
- Приложение запускается на Windows, показывает навигацию по пустым экранам.
- Переключаются язык и тема.
- Иконка в трее и горячая клавиша работают.
- БД создаётся, миграции применяются.
- Analyze чистый, тесты зелёные, сборка Windows проходит.
- /docs заполнены (INDEX, context, decisions, stage-00).
- Никаких секретов в репозитории.

## ФОРМАТ ОТВЕТА
1. Покажи финальное дерево папок.
2. Выведи файлы по одному с полным содержимым (pubspec, main.dart,
   app/*, core/*, data/*, features/*/presentation/*, l10n/*, тесты,
   docs/*). Не сокращай критичные файлы.
3. В конце — чек-лист критериев приёмки с отметками.
4. Дай команды для локальной проверки.
5. Запиши в decisions.md минимум 5 записей о ключевых решениях этапа.