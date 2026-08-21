import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/widgets/verse_study_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('outils horizontaux lisibles sur petit écran sombre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VerseStudySheet(
            book: BibleBook(
              id: 1,
              name: 'Genèse',
              abbreviation: 'Gn',
              testament: 'Ancien Testament',
              chaptersCount: 50,
            ),
            chapter: 1,
            versionId: 1,
            verses: const [
              VerseStudyTarget(
                verseId: 1,
                verseNumber: 1,
                verseText: 'Au commencement, Dieu créa les cieux et la terre.',
              ),
            ],
            initialVerseNumber: 1,
            loadStudy: (_) async => const VerseStudyData(
              strongWords: [],
              crossReferences: [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Lexique'), findsOneWidget);
    expect(find.text('Dictionnaire'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('study-tool-dictionary')),
      const Offset(-500, 0),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text('Comparer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
