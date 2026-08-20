import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/screens/nave_topics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NaveScreenRepository extends NaveRepository {
  final Object? error;
  final List<NaveTopic> topics;
  final List<NaveReference> topicReferences;

  const _NaveScreenRepository({
    this.error,
    this.topics = const [],
    this.topicReferences = const [],
  });

  Future<List<NaveTopic>> _topics() async {
    if (error != null) throw error!;
    return topics;
  }

  @override
  Future<List<NaveTopic>> browse({
    int limit = 6000,
    AppLanguage? language,
  }) =>
      _topics();

  @override
  Future<List<NaveTopic>> search(
    String value, {
    int limit = 100,
    AppLanguage? language,
  }) =>
      _topics();

  @override
  Future<List<NaveReference>> references(
    int topicId, {
    AppLanguage? language,
  }) async {
    if (error != null) throw error!;
    return topicReferences;
  }
}

void main() {
  const love = NaveTopic(
    id: 7,
    title: 'Amour',
    titleEnglish: 'LOVE',
    translationStatus: 'manual',
  );
  const untranslated = NaveReference(
    subtopicId: 11,
    subtopic: 'Toward enemies',
    subtopicEnglish: 'Toward enemies',
    bookId: 40,
    bookName: 'Matthieu',
    chaptersCount: 28,
    chapter: 5,
    verseStart: 44,
  );

  testWidgets('la liste privilégie le titre français et conserve l’anglais',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NaveTopicsScreen(
        key: ValueKey('missing'),
        initialQuery: 'amour',
        repository: _NaveScreenRepository(topics: [love]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Amour'), findsOneWidget);
    expect(find.text('LOVE'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'amour');
  });

  testWidgets('le détail indique une section anglaise et ouvre sa référence',
      (tester) async {
    NaveReference? opened;
    await tester.pumpWidget(MaterialApp(
      home: NaveTopicDetailScreen(
        topic: love,
        repository: const _NaveScreenRepository(
          topicReferences: [untranslated],
        ),
        onOpenReference: (reference) => opened = reference,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Original anglais : LOVE'), findsOneWidget);
    expect(find.text('Non traduite'), findsOneWidget);
    expect(find.byTooltip('Section non encore traduite'), findsOneWidget);
    await tester.tap(find.text('Matthieu 5:44'));
    expect(opened, same(untranslated));
  });

  testWidgets('distingue ressource absente, base vide et erreur',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NaveTopicsScreen(
        repository: _NaveScreenRepository(
          error: ResourceNotInstalledException('Nave'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bible thématique Nave non installée.'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: NaveTopicsScreen(
        key: ValueKey('empty'),
        repository: _NaveScreenRepository(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aucun thème trouvé.'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: NaveTopicsScreen(
        key: const ValueKey('error'),
        repository: _NaveScreenRepository(error: StateError('SQLite')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger Nave.'), findsOneWidget);
  });
}
