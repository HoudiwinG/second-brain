import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/app/di.dart';
import 'package:second_brain/core/result/result.dart';
import 'package:second_brain/features/notes/domain/note.dart';
import 'package:second_brain/features/quick_capture/presentation/quick_capture_dialog.dart';
import 'package:second_brain/l10n/generated/app_localizations.dart';

/// Репозиторий, который падает при создании заметки.
class _ThrowingNotesRepository implements NotesRepository {
  @override
  Future<Result<Note>> create(NoteDraft draft) async {
    throw StateError('тест: БД недоступна');
  }

  @override
  Future<Result<Note?>> getById(int id, {bool includeDeleted = false}) async =>
      const Result.success(null);

  @override
  Future<Result<List<Note>>> list({
    bool includeDeleted = false,
    bool forLlm = false,
  }) async => const Result.success([]);

  @override
  Future<Result<Note>> update(int id, NoteDraft draft) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> softDelete(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> restore(int id) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets(
    'ошибка репозитория разблокирует кнопку и показывает сообщение (R02-006)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWith(
              (ref) async => _ThrowingNotesRepository(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showQuickCaptureDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Заметка');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureDialog), findsOneWidget);
      expect(find.text('Unexpected error'), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    },
  );
}
