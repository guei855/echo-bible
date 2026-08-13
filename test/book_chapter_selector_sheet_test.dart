import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/widgets/book_chapter_selector_sheet.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ouvre un livre et retourne le chapitre choisi', (tester) async {
    BookChapterSelection? selection;
    final books = [
      BibleBook(
        id: 1,
        name: 'Genèse',
        abbreviation: 'GEN',
        testament: 'Ancien',
        chaptersCount: 3,
      ),
      BibleBook(
        id: 2,
        name: 'Exode',
        abbreviation: 'EXO',
        testament: 'Ancien',
        chaptersCount: 2,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selection = await BookChapterSelectorSheet.show(
                context,
                currentBookId: 1,
                currentChapter: 1,
                darkMode: false,
                initialBooks: books,
              );
            },
            child: const Text('Choisir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
    expect(find.text('Livres'), findsOneWidget);
    expect(find.text('Genèse'), findsOneWidget);
    expect(find.text('Exode'), findsOneWidget);

    final surface = tester.widget<Material>(
      find.byKey(const ValueKey('book-selector-surface')),
    );
    expect(surface.color, AppColors.surfaceLight);
    final currentBook = tester.widget<Text>(find.text('Genèse'));
    expect(currentBook.style?.color, AppColors.primary);

    await tester.tap(find.text('Genèse'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();

    expect(selection?.book.name, 'Genèse');
    expect(selection?.chapter, 2);
  });
}
