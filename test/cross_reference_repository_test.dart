import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('requête les cinq passages de référence, triés par score', () async {
    const repository = CrossReferenceRepository();
    const expectedCounts = {
      (1, 1, 1): 62,
      (43, 3, 16): 23,
      (45, 8, 28): 43,
      (19, 23, 1): 22,
      (23, 53, 5): 19,
    };
    for (final entry in expectedCounts.entries) {
      expect(
        await repository.countForVerse(
            entry.key.$1, entry.key.$2, entry.key.$3),
        entry.value,
      );
      final results = await repository.forVerse(
        entry.key.$1,
        entry.key.$2,
        entry.key.$3,
      );
      expect(results, isNotEmpty, reason: '${entry.key}');
      expect(results.every((result) => result.text.trim().isNotEmpty), isTrue);
      final scores = results.map((result) => result.score ?? -9999).toList();
      expect(
          scores, orderedEquals([...scores]..sort((a, b) => b.compareTo(a))));
    }
  });

  test('conserve les plages et charge tous leurs versets', () async {
    const repository = CrossReferenceRepository();
    final results = await repository.forVerse(43, 3, 16);
    final range = results
        .firstWhere((reference) => reference.verseEnd > reference.verseStart);
    expect(range.verseLabel, contains('-'));
    expect(range.text.trim().split(RegExp(r'\s+')).length, greaterThan(5));
  });

  test('utilise dynamiquement LSG, Darby, Ostervald et NCL', () async {
    const repository = CrossReferenceRepository();
    final versions = await BibleVersionRepository.getInstalledVersions();
    final relevant = versions.where(
      (version) =>
          ['LSG', 'DARBY', 'OST', 'NCL'].contains(version.abbreviation),
    );
    expect(relevant, hasLength(4));
    final texts = <String>{};
    for (final version in relevant) {
      final result = (await repository.forVerse(
        43,
        3,
        16,
        limit: 1,
        versionId: version.id,
      ))
          .single;
      expect(result.requestedVersionId, version.id);
      expect(result.text, isNotEmpty);
      expect(result.usedLsgFallback, isFalse);
      texts.add(result.text);
    }
    expect(texts, hasLength(4));
  });

  test('API inverse exploite les plages cibles', () async {
    const repository = CrossReferenceRepository();
    final sources = await repository.findReferencesToVerse(45, 5, 8);
    expect(sources, isNotEmpty);
    expect(
      sources.every((row) => (row['score'] as int?) != null),
      isTrue,
    );
  });

  test('ressource absente et DB corrompue sont distinguables', () async {
    final directory = await Directory.systemTemp.createTemp('xref-state-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(rootDirectory: directory);
    expect(
      await manager.state(OfflineResourceId.crossReferences),
      OfflineResourceState.notInstalled,
    );
    final corrupt = File('${directory.path}/corrupt.db');
    await corrupt.writeAsString('<html>not sqlite</html>');
    expect(
      () => ResourceManager.validateSqliteFile(corrupt.path),
      throwsA(anything),
    );
  });
}
