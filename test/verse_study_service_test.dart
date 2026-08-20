import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/study/services/verse_study_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  test('charge les mots Strong et leurs occurrences depuis bible.db', () async {
    final db = await DatabaseService.database;
    final firstVerse = await db.query(
      'verses',
      columns: ['id'],
      orderBy: 'id ASC',
      limit: 1,
    );
    final verseId = firstVerse.single['id'] as int;

    final study = await VerseStudyService.loadVerse(verseId);

    expect(study.strongWords, isNotEmpty);
    expect(study.strongWords.map((word) => word.code), contains('H7225'));
    expect(study.strongWords.first.inferredLanguage, 'Hébreu');
    expect(study.strongWords.first.word, 'commencement');
    // Les références sont chargées paresseusement à l’ouverture de leur onglet.
    expect(study.crossReferences, isEmpty);

    final occurrences = await VerseStudyService.loadOccurrences('H7225');
    expect(occurrences, isNotEmpty);
    expect(occurrences.first.bookName, 'Genèse');
    expect(occurrences.first.chapterNumber, 1);
    expect(occurrences.first.verseNumber, 1);

    final versions = await BibleVersionRepository.getInstalledVersions();
    final martin = versions.singleWhere(
      (version) => version.abbreviation == 'MAR',
    );
    final martinOccurrences = await VerseStudyService.loadOccurrences(
      'H7225',
      versionId: martin.id,
    );
    expect(martinOccurrences.first.verseText, contains('DIEU'));

    final genesisOneFour = await db.query(
      'verses',
      columns: ['id'],
      where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
      whereArgs: [1, 1, 4],
      limit: 1,
    );
    final genesisStudy = await VerseStudyService.loadVerse(
      genesisOneFour.single['id'] as int,
    );
    final h3588 = genesisStudy.strongWords.singleWhere(
      (word) => word.code == 'H3588',
    );
    expect(h3588.word, 'que');
    expect(h3588.originalWord, 'כִּי');
    expect(h3588.transliteration, 'ki');
    expect(
      genesisStudy.strongWords.every(
        (word) => word.word.trim().isNotEmpty && word.order > 0,
      ),
      isTrue,
    );
    expect(genesisStudy.crossReferences, isEmpty);

    final selectedGenesis = await VerseStudyService.loadVerse(
      verseId,
      selectedText: 'commencement',
    );
    expect(selectedGenesis.strongWords, hasLength(1));
    expect(selectedGenesis.strongWords.single.code, 'H7225');

    final johnOneOne = await db.query(
      'verses',
      columns: ['id'],
      where: 'book_id=? AND chapter_number=? AND verse_number=?',
      whereArgs: [43, 1, 1],
      limit: 1,
    );
    final selectedWord = await VerseStudyService.loadVerse(
      johnOneOne.single['id'] as int,
      selectedText: 'Parole',
    );
    expect(selectedWord.strongWords.map((word) => word.code).toSet(), {
      'G3056',
    });
    expect(selectedWord.strongWords.first.word, 'Parole');

    final h3588Occurrences = await VerseStudyService.loadOccurrences('H3588');
    expect(
      h3588Occurrences.any(
        (occurrence) =>
            occurrence.bookId == 1 &&
            occurrence.chapterNumber == 1 &&
            occurrence.verseNumber == 4,
      ),
      isTrue,
    );
  });
}
