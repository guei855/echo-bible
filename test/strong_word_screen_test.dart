import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('masque les champs Strong absents et identifie Extended Strong', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StrongWordScreen(
          word: const VerseStrongWord(
            id: 1,
            order: 1,
            word: '/ב',
            code: 'H9003',
            language: 'Hébreu',
            transliteration: 'b',
            morphology: 'Prefix',
            shortDefinition: 'in/on/with',
            source: 'TBESH',
            license: 'CC BY 4.0',
            numberKind: StrongNumberKind.extendedGrammar,
          ),
          occurrences: Future.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('H9003'), findsWidgets);
    expect(find.text('/ב'), findsWidgets);
    expect(find.text('Extended Strong grammatical'), findsOneWidget);
    expect(find.text('Morphologie'), findsOneWidget);
    expect(find.text('Prefix'), findsOneWidget);
    expect(find.text('in/on/with'), findsOneWidget);
    expect(find.text('Prononciation'), findsNothing);
    expect(find.text('Non disponible'), findsNothing);
    expect(
      find.text('Traduction française non disponible pour cette entrée.'),
      findsOneWidget,
    );
  });
}
