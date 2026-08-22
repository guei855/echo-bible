import 'package:echo_bible/features/bible/widgets/verse_selection_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'Comparer Étudier Ajouter restent entiers sur ${width.toInt()} px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            bottomNavigationBar: VerseSelectionActionBar(
              selectionCount: 1,
              onHighlight: () {},
              onUnderline: () {},
              onNote: () {},
              onFavorite: () {},
              onCopy: () {},
              onShare: () {},
              onCompare: () {},
              onStudy: () {},
              onAddToStudy: () {},
            ),
          ),
        ));

        expect(find.text('Comparer'), findsOneWidget);
        expect(find.text('Étudier'), findsOneWidget);
        expect(find.text('Ajouter'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
