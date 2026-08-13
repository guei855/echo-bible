import 'package:echo_bible/features/dictionary/screens/dictionary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('explique honnêtement l’absence du dictionnaire français',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DictionaryScreen(availability: Future<bool>.value(false)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Dictionnaire biblique'), findsOneWidget);
    expect(find.text('Dictionnaire biblique français'), findsOneWidget);
    expect(find.textContaining('Ressource en préparation'), findsWidgets);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(find.textContaining('Vigouroux'), findsOneWidget);
  });

  testWidgets('affiche la recherche quand l’état installé est simulé', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DictionaryScreen(availability: Future<bool>.value(true)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Rechercher un mot…'), findsOneWidget);
    expect(find.text('Ressource en préparation'), findsNothing);
  });
}
