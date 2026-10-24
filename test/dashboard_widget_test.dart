import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/app.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/data/repositories/finance_repository.dart';
import 'package:second_brain/data/repositories/ideas_repository.dart';
import 'package:second_brain/data/repositories/notes_repository.dart';
import 'package:second_brain/data/repositories/tasks_repository.dart';
import 'package:second_brain/features/finance/domain/finance_transaction.dart';
import 'package:second_brain/features/ideas/domain/idea_entry.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/quick_capture/presentation/quick_capture_dialog.dart';
import 'package:second_brain/features/tasks/domain/task_item.dart';

import 'helpers/in_memory_db.dart';

/// Репозиторий, который позволяет придержать загрузку (R02-012).
class _GatedTasksRepository extends DriftTasksRepository {
  _GatedTasksRepository(super.db);

  Completer<void>? gate;

  @override
  Future<Result<List<TaskItem>>> list({
    TaskStatus? status,
    bool includeDeleted = false,
    bool forLlm = false,
  }) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return super.list(
      status: status,
      includeDeleted: includeDeleted,
      forLlm: forLlm,
    );
  }
}

/// Widget-тест дашборда: сводка дня и быстрый ввод поверх in-memory БД.
void main() {
  testWidgets('дашборд показывает сводку и создаёт задачу из быстрого ввода', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = InMemoryDbFactory.open();
    addTearDown(db.close);

    final notes = DriftNotesRepository(db);
    final tasks = DriftTasksRepository(db);
    final ideas = DriftIdeasRepository(db);
    final finance = DriftFinanceRepository(db);

    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12).toUtc();

    await notes.create(
      const NoteDraft(title: 'Заметка для дашборда', body: 'Текст заметки'),
    );
    await tasks.create(TaskDraft(title: 'Позвонить клиенту', dueAt: noon));
    await ideas.create(const IdeaDraft(text: 'Идея для дашборда'));
    await finance.create(
      FinanceDraft(
        amount: 1000,
        type: FinanceTransactionType.income,
        date: now.toUtc(),
      ),
    );
    // Операция в другой валюте не должна попадать в сводку (R02-011).
    await finance.create(
      FinanceDraft(
        amount: 500,
        currency: 'USD',
        type: FinanceTransactionType.income,
        date: now.toUtc(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => Future.value(db)),
          // Фоновый планировщик не нужен в widget-тесте.
          reminderSchedulerProvider.overrideWithValue(null),
        ],
        child: const SecondBrainApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text("Today's tasks"), findsOneWidget);
    expect(find.text('Позвонить клиенту'), findsOneWidget);
    expect(find.text('Recent notes'), findsOneWidget);
    expect(find.text('Заметка для дашборда'), findsOneWidget);
    expect(find.text('Recent ideas'), findsOneWidget);
    expect(find.text('Идея для дашборда'), findsOneWidget);
    expect(find.text("This month's finance"), findsOneWidget);

    // Сводка только в RUB и с явной подписью валюты.
    expect(find.text('Income · RUB'), findsOneWidget);
    expect(find.text('1000.00'), findsNWidgets(2)); // доход и баланс
    expect(find.text('1500.00'), findsNothing);
    expect(find.text('500.00'), findsNothing);

    // Быстрое действие «Task» открывает общий диалог и сохраняет задачу.
    await tester.tap(find.text('Task').first);
    await tester.pumpAndSettle();

    expect(find.byType(QuickCaptureDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Задача из диалога');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickCaptureDialog), findsNothing);
    final saved = (await tasks.list()).unwrap();
    expect(saved.map((task) => task.title), contains('Задача из диалога'));
  });

  testWidgets('RefreshIndicator ждёт завершения загрузки (R02-012)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = InMemoryDbFactory.open();
    addTearDown(db.close);
    final tasks = _GatedTasksRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => Future.value(db)),
          tasksRepositoryProvider.overrideWith((ref) async => tasks),
          reminderSchedulerProvider.overrideWithValue(null),
        ],
        child: const SecondBrainApp(),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    tasks.gate = Completer<void>();
    var completed = false;
    final refresh = indicator.onRefresh().then((_) => completed = true);

    await tester.pump();
    expect(completed, isFalse);

    tasks.gate!.complete();
    await tester.pumpAndSettle();
    await refresh;

    expect(completed, isTrue);
    expect(find.text("Today's tasks"), findsOneWidget);
  });
}
