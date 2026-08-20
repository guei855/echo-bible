import 'package:echo_bible/features/bible/widgets/verse_selection_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('actions de sélection lisibles en mode ${brightness.name}', (
      tester,
    ) async {
      var studied = false;
      var highlighted = false;
      var compared = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            bottomNavigationBar: VerseSelectionActionBar(
              selectionCount: 2,
              onHighlight: () => highlighted = true,
              onUnderline: () {},
              onNote: null,
              onFavorite: () {},
              onCopy: () {},
              onShare: () {},
              onCompare: () => compared = true,
              onStudy: () => studied = true,
            ),
          ),
        ),
      );

      for (final label in [
        'Surligner',
        'Souligner',
        'Note',
        'Favoris',
        'Copier',
        'Partager',
        'COMPARER',
        'ÉTUDIER',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Surligner'));
      await tester.tap(find.text('ÉTUDIER'));
      await tester.tap(find.text('COMPARER'));
      expect(highlighted, isTrue);
      expect(studied, isTrue);
      expect(compared, isTrue);
    });
  }

  testWidgets('favori change immédiatement et reste actif au rechargement',
      (tester) async {
    var persisted = false;

    Widget favoriteApp() => MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: VerseSelectionActionBar(
                selectionCount: 1,
                isFavorite: persisted,
                onHighlight: () {},
                onUnderline: () {},
                onNote: () {},
                onFavorite: () => setState(() => persisted = !persisted),
                onCopy: () {},
                onShare: () {},
                onCompare: () {},
                onStudy: () {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(favoriteApp());
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('selected-verses-favorite-action')),
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(favoriteApp());
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('selected-verses-favorite-action')),
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}
