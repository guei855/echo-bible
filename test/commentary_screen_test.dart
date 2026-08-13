import 'package:echo_bible/features/study/screens/commentary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reference in const [
    (bookId: 43, chapter: 3, verse: 16, label: 'Jean 3:16'),
    (bookId: 45, chapter: 8, verse: 28, label: 'Romains 8:28'),
    (bookId: 46, chapter: 2, verse: 4, label: '1 Corinthiens 2:4'),
  ]) {
    testWidgets('annonce honnêtement la ressource absente — ${reference.label}',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryScreen(
            bookId: reference.bookId,
            chapter: reference.chapter,
            verse: reference.verse,
            reference: reference.label,
            availability: Future<bool>.value(false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Les commentaires bibliques français ne sont pas encore installés.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ressource en préparation'), findsWidgets);
      expect(find.text('Télécharger'), findsNothing);
    });
  }
}
