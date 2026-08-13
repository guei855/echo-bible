import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
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

  test('expose les quatre versions avec leurs textes hors ligne', () async {
    final versions = await BibleVersionRepository.getInstalledVersions();
    expect(
      versions.map((version) => version.abbreviation),
      containsAll(['LSG', 'DARBY', 'OST', 'NCL']),
    );

    final db = await DatabaseService.database;
    final genesis = await db.query(
      'books',
      columns: ['id'],
      where: 'abbreviation = ?',
      whereArgs: ['GEN'],
      limit: 1,
    );
    final bookId = genesis.single['id'] as int;

    final chapterTexts = <String>[];
    for (final version in versions) {
      final verses = await BibleVersionRepository.getChapter(
        bookId: bookId,
        chapterNumber: 1,
        versionId: version.id,
      );
      chapterTexts.add(verses[1]['text'] as String);
    }

    expect(chapterTexts.toSet(), hasLength(4));
    final byVersion = {
      for (var index = 0; index < versions.length; index++)
        versions[index].abbreviation: chapterTexts[index],
    };
    expect(byVersion['OST'], startsWith('Or'));
    expect(byVersion['DARBY'], contains('désolation et vide'));
    expect(byVersion['NCL'], contains('informe et vide'));
  });

  test('mémorise la version choisie', () async {
    final versions = await BibleVersionRepository.getInstalledVersions();
    final selected = versions.last.id;
    await BibleVersionRepository.setActiveVersion(selected);
    expect(
        await BibleVersionRepository.getSelectedVersionId(versions), selected);
  });

  test('revient automatiquement à LSG si la version active est absente',
      () async {
    SharedPreferences.setMockInitialValues({'selected_bible_version_id': 999});
    final versions = await BibleVersionRepository.getInstalledVersions();
    final selected =
        await BibleVersionRepository.getSelectedVersionId(versions);
    expect(
      versions.firstWhere((version) => version.id == selected).isDefault,
      isTrue,
    );
  });

  test('charge les passages de comparaison demandés dans chaque version',
      () async {
    final versions = await BibleVersionRepository.getInstalledVersions();
    final db = await DatabaseService.database;

    for (final passage in const [
      (book: 'GEN', chapter: 1, verse: 1),
      (book: 'PSA', chapter: 23, verse: 1),
      (book: 'JHN', chapter: 3, verse: 16),
    ]) {
      final books = await db.query(
        'books',
        columns: ['id'],
        where: 'abbreviation = ?',
        whereArgs: [passage.book],
        limit: 1,
      );
      expect(books, isNotEmpty, reason: passage.book);
      for (final version in versions) {
        final rows = await BibleVersionRepository.getChapter(
          bookId: books.single['id'] as int,
          chapterNumber: passage.chapter,
          versionId: version.id,
        );
        final verse = rows.where(
          (row) => row['verse_number'] == passage.verse,
        );
        expect(verse, isNotEmpty, reason: '${passage.book} ${version.code}');
        expect(verse.single['text'], isNotEmpty);
      }
    }
  });
}
