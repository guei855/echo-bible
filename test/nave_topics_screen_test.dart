import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/screens/nave_topics_screen.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

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

    expect(find.text('AMOUR'), findsOneWidget);
    expect(find.textContaining('LOVE'), findsOneWidget);
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
    expect(find.text('Non encore traduit'), findsOneWidget);
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
    expect(find.text('Bible thématique non installée'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: NaveTopicsScreen(
        key: ValueKey('empty'),
        repository: _NaveScreenRepository(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Commencez à saisir un thème.'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: NaveTopicsScreen(
        key: const ValueKey('error'),
        repository: _NaveScreenRepository(error: StateError('SQLite')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger la Bible thématique.'),
        findsOneWidget);
  });

  testWidgets('sélectionne trois références et prépare un bloc étude ordonné',
      (tester) async {
    final now = DateTime(2026, 8, 20);
    StudyBlock? inserted;
    PersonalStudy? opened;
    const references = [
      NaveReference(
        id: 101,
        subtopicId: 11,
        subtopic: 'Amour de Dieu',
        subtopicEnglish: 'LOVE OF GOD',
        bookId: 43,
        bookName: 'Jean',
        chaptersCount: 21,
        chapter: 3,
        verseStart: 16,
      ),
      NaveReference(
        id: 102,
        subtopicId: 11,
        subtopic: 'Amour de Dieu',
        subtopicEnglish: 'LOVE OF GOD',
        bookId: 45,
        bookName: 'Romains',
        chaptersCount: 16,
        chapter: 5,
        verseStart: 8,
      ),
      NaveReference(
        id: 103,
        subtopicId: 11,
        subtopic: 'Amour de Dieu',
        subtopicEnglish: 'LOVE OF GOD',
        bookId: 62,
        bookName: '1 Jean',
        chaptersCount: 5,
        chapter: 4,
        verseStart: 8,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: NaveTopicDetailScreen(
        topic: love,
        repository: const _NaveScreenRepository(
          topicReferences: references,
        ),
        studyDestination: (_, block) async {
          inserted = block;
          return PersonalStudy(
            id: 9,
            title: 'Prédication dimanche',
            blocks: [block],
            createdAt: now,
            updatedAt: now,
          );
        },
        onStudyOpened: (study) => opened = study,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Jean 3:16'));
    await tester.tap(find.text('Romains 5:8'));
    await tester.tap(find.text('1 Jean 4:8'));
    await tester.pumpAndSettle();
    expect(find.text('3 sélectionnées'), findsOneWidget);

    expect(find.byKey(const Key('nave-copy-selection')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nave-add-to-study')));
    await tester.pumpAndSettle();
    expect(inserted?.type, StudyBlockType.nave);
    expect(inserted?.payload['references'], [
      'Jean 3:16',
      'Romains 5:8',
      '1 Jean 4:8',
    ]);
    expect(opened?.title, 'Prédication dimanche');
  });

  testWidgets('ouvre le lecteur au verset et conserve la version active',
      (tester) async {
    const routed = NaveReference(
      id: 201,
      subtopicId: 11,
      subtopic: 'Amour de Dieu',
      subtopicEnglish: 'LOVE OF GOD',
      bookId: 43,
      bookName: 'Jean',
      chaptersCount: 21,
      chapter: 3,
      verseStart: 16,
      verseEnd: 18,
      versionId: 1,
    );
    await tester.pumpWidget(const MaterialApp(
      home: NaveTopicDetailScreen(
        topic: love,
        repository: _NaveScreenRepository(topicReferences: [routed]),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean 3:16-18'));
    await tester.pump(const Duration(milliseconds: 400));

    final reader = tester.widget<ChapterReaderScreen>(
      find.byType(ChapterReaderScreen, skipOffstage: false),
    );
    expect(reader.book.id, 43);
    expect(reader.initialChapter, 3);
    expect(reader.initialVerse, 16);
    expect(reader.initialVersionId, 1);
  });
}
