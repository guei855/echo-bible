import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/lexicon/screens/lexicon_screen.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StrongEntry entry({
    required int id,
    required String code,
    required String original,
    required String transliteration,
    required String language,
  }) =>
      StrongEntry(
        id: id,
        strongNumber: code,
        extendedStrongNumber: code,
        language: language,
        originalWord: original,
        transliteration: transliteration,
        morphology: code.startsWith('G') ? 'N-NSM' : 'Ncmpa',
        gloss: code == 'H430' ? 'God, gods' : 'word, speech',
        source: code.startsWith('G') ? 'TBESG' : 'TBESH',
        license: 'CC BY 4.0',
      );

  late StrongEntry hebrew;
  late StrongEntry greek;

  setUp(() {
    hebrew = entry(
      id: 1,
      code: 'H430',
      original: 'אֱלֹהִים',
      transliteration: 'elohim',
      language: 'Hébreu',
    );
    greek = entry(
      id: 2,
      code: 'G3056',
      original: 'λόγος',
      transliteration: 'logos',
      language: 'Grec',
    );
  });

  testWidgets('strong.db absente propose un seul téléchargement Strong',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LexiconScreen(
        loadResourceState: () async => OfflineResourceState.notInstalled,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Télécharger Strong'), findsOneWidget);
    expect(find.textContaining('lexique.db'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('recherche hébraïque RTL et grec polytonique dans strong.db',
      (tester) async {
    final searched = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: LexiconScreen(
        loadResourceState: () async => OfflineResourceState.installed,
        searchEntries: (query) async {
          searched.add(query);
          return [hebrew, greek];
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('lexicon-search-field')),
      'H430',
    );
    await tester.tap(find.byKey(const Key('lexicon-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lexicon-entry-H430')), findsOneWidget);
    expect(find.text('אֱלֹהִים'), findsOneWidget);
    final original = find.byKey(const Key('lexicon-original-H430'));
    final directionality = tester.widget<Directionality>(
      find.ancestor(of: original, matching: find.byType(Directionality)).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);

    await tester.tap(find.text('Grec'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lexicon-search-field')),
      'logos',
    );
    await tester.tap(find.byKey(const Key('lexicon-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('G3056'), findsOneWidget);
    expect(find.text('λόγος'), findsOneWidget);
    expect(find.textContaining('Nom · Nominatif · Singulier · Masculin'),
        findsOneWidget);
    expect(searched, ['H430', 'logos']);
  });

  testWidgets('une erreur termine toujours le chargement', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LexiconScreen(
        loadResourceState: () async => OfflineResourceState.installed,
        searchEntries: (_) async => throw StateError('base indisponible'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lexicon-search-field')),
      'grâce',
    );
    await tester.tap(find.byKey(const Key('lexicon-search-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Impossible d’interroger'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
