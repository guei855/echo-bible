import 'dart:async';

import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DictionaryEntry _entry(String title) => DictionaryEntry(
      id: title.hashCode,
      headword: title,
      content: 'Article $title',
      source: 'test',
      sourceKind: 'test',
      sourceUrl: 'https://example.test',
      quality: 'test',
    );

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

  testWidgets('A, B, C puis Abraham terminent sans loader permanent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DictionaryScreen(
          availability: Future<bool>.value(true),
          letterLoader: (letter) async => [_entry('Article $letter')],
          searchLoader: (query) async => [_entry(query)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Article A'), findsOneWidget);
    expect(find.byKey(const Key('dictionary-loading')), findsNothing);

    for (final letter in ['B', 'C']) {
      await tester.tap(find.byKey(Key('dictionary-letter-$letter')));
      await tester.pumpAndSettle();
      expect(find.text('Article $letter'), findsOneWidget);
      expect(find.byKey(const Key('dictionary-loading')), findsNothing);
    }

    await tester.enterText(find.byType(TextField), 'Abraham');
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    expect(find.text('Abraham'), findsNWidgets(2));
    expect(find.byKey(const Key('dictionary-loading')), findsNothing);
  });

  testWidgets('0 résultat et erreur retirent toujours le loader', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DictionaryScreen(
          availability: Future<bool>.value(true),
          letterLoader: (_) async => [_entry('Article A')],
          searchLoader: (query) async {
            if (query == 'Erreur') throw StateError('test');
            return const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Absent');
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun article trouvé.'), findsOneWidget);
    expect(find.byKey(const Key('dictionary-loading')), findsNothing);

    await tester.enterText(find.byType(TextField), 'Erreur');
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger le dictionnaire.'), findsOneWidget);
    expect(find.byKey(const Key('dictionary-loading')), findsNothing);
  });

  testWidgets('une ancienne réponse alphabétique ne remplace pas la nouvelle', (
    tester,
  ) async {
    final pending = <String, Completer<List<DictionaryEntry>>>{};
    await tester.pumpWidget(
      MaterialApp(
        home: DictionaryScreen(
          availability: Future<bool>.value(true),
          letterLoader: (letter) =>
              (pending[letter] ??= Completer<List<DictionaryEntry>>()).future,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('dictionary-loading')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dictionary-letter-B')));
    await tester.pump();
    pending['B']!.complete([_entry('Article B')]);
    await tester.pump();
    expect(find.text('Article B'), findsOneWidget);
    pending['A']!.complete([_entry('Article A obsolète')]);
    await tester.pump();
    expect(find.text('Article B'), findsOneWidget);
    expect(find.text('Article A obsolète'), findsNothing);
    expect(find.byKey(const Key('dictionary-loading')), findsNothing);
  });
}
