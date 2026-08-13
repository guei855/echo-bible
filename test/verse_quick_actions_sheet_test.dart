import 'package:echo_bible/features/bible/widgets/verse_quick_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche les six actions et conserve l’accès à l’étude', (
    tester,
  ) async {
    VerseQuickAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await VerseQuickActionsSheet.show(
                context,
                reference: 'Actes des Apôtres 18:15',
                verseText: 'Mais, s’il s’agit de discussions sur une parole…',
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    for (final label in [
      'Copier',
      'Partager',
      'Surligner',
      'Note',
      'Favoris',
      'Comparer',
      'Étudier ce verset',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    expect(selected, VerseQuickAction.note);
  });
}
