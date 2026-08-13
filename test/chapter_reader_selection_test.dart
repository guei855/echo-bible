import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('le numéro du verset active la sélection multiple', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChapterReaderScreen(
          book: BibleBook(
            id: 1,
            name: 'Genèse',
            abbreviation: 'Gn',
            testament: 'Ancien Testament',
            chaptersCount: 50,
          ),
          initialVerses: const [
            {
              'id': 1,
              'book_id': 1,
              'chapter_number': 1,
              'verse_number': 1,
              'text': 'Au commencement, Dieu créa les cieux et la terre.',
              'uses_default_text': 0,
            },
            {
              'id': 2,
              'book_id': 1,
              'chapter_number': 1,
              'verse_number': 2,
              'text': 'La terre était informe et vide.',
              'uses_default_text': 0,
            },
          ],
        ),
      ),
    );
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byKey(const Key('verse-1')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const Key('verse-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('verse-number-1')));
    await tester.pump();
    expect(find.text('1 verset sélectionné'), findsOneWidget);
    expect(find.text('ÉTUDIER'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verse-number-2')));
    await tester.pump();
    expect(find.text('2 versets sélectionnés'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer la sélection'));
    await tester.pump();
    expect(find.text('2 versets sélectionnés'), findsNothing);
  });

  testWidgets('positionne le lecteur sur le verset demandé', (tester) async {
    final verses = List.generate(
      20,
      (index) => <String, dynamic>{
        'id': index + 1,
        'book_id': 1,
        'chapter_number': 3,
        'verse_number': index + 1,
        'text': 'Texte du verset ${index + 1}.',
        'uses_default_text': 0,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChapterReaderScreen(
          book: BibleBook(
            id: 1,
            name: 'Genèse',
            abbreviation: 'Gn',
            testament: 'Ancien Testament',
            chaptersCount: 50,
          ),
          initialChapter: 3,
          initialVerse: 15,
          initialVerses: verses,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('verse-15')), findsOneWidget);
  });
}
