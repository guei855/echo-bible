import 'package:echo_bible/features/bible/screens/note_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('présente le verset et active la sauvegarde avec une description',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteEditorScreen(
          reference: '1 Corinthiens 2:2',
          verseText:
              'Car je n’ai pas eu la pensée de savoir parmi vous autre chose que Jésus-Christ.',
        ),
      ),
    );

    expect(find.text('Note'), findsOneWidget);
    expect(find.text('1 Corinthiens 2:2'), findsNWidgets(2));
    expect(find.text('Titre (facultatif)'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    var saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sauvegarder'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'Ma réflexion');
    await tester.pump();
    saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sauvegarder'),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('ferme la page après sauvegarde sans erreur de contrôleur', (
    tester,
  ) async {
    NoteScreenResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<NoteScreenResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => const NoteEditorScreen(
                    reference: 'Genèse 1:2',
                    verseText: 'La terre était informe et vide.',
                  ),
                ),
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ma note');
    await tester.pump();
    await tester.tap(find.text('Sauvegarder'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result?.action, NoteScreenAction.save);
    expect(result?.description, 'Ma note');
  });
}
