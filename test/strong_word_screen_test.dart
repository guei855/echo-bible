import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('décode une morphologie grecque courante en français', () {
    const word = VerseStrongWord(
      id: 1,
      order: 1,
      word: 'Parole',
      code: 'G3056',
      morphology: 'N-NSM',
    );
    expect(word.morphologyInFrench, 'Nom · Nominatif · Singulier · Masculin');
  });

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
            originalWord: '/ב',
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
    expect(find.text('Prefix'), findsNWidgets(2));
    expect(find.text('in/on/with'), findsOneWidget);
    expect(find.text('Prononciation'), findsNothing);
    expect(find.text('Non disponible'), findsNothing);
    expect(
      find.text(
        'Définition française non disponible dans les ressources installées.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pagine 30 occurrences et ouvre le lecteur au bon verset',
      (tester) async {
    final offsets = <int>[];
    StrongOccurrence? opened;
    List<StrongOccurrence> page(int start, int count) => [
          for (var index = start; index < start + count; index++)
            StrongOccurrence(
              bookId: 43,
              bookName: 'Jean',
              chaptersCount: 21,
              chapterNumber: 1,
              verseNumber: index + 1,
              verseText: 'Texte ${index + 1}',
              originalForm: 'λόγος',
              morphology: 'N-NSM',
              morphologyDescription: 'Nom · Nominatif · Singulier · Masculin',
            ),
        ];
    await tester.pumpWidget(MaterialApp(
      home: StrongWordScreen(
        word: const VerseStrongWord(
          id: 1,
          order: 1,
          word: 'λόγος',
          code: 'G3056',
          language: 'Grec',
        ),
        occurrenceLoader: (limit, offset) async {
          offsets.add(offset);
          return offset == 0 ? page(0, limit) : page(offset, 1);
        },
        onOpenOccurrence: (occurrence) => opened = occurrence,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jean 1:1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Afficher plus'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Afficher plus'));
    await tester.pumpAndSettle();
    expect(offsets, [0, 30]);

    await tester.ensureVisible(find.text('Jean 1:1'));
    await tester.tap(find.text('Jean 1:1'));
    await tester.pump();
    expect(opened?.bookName, 'Jean');
    expect(opened?.chapterNumber, 1);
    expect(opened?.verseNumber, 1);
  });
}
