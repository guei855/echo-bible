import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
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

  test('recherche les thèmes prioritaires en français hors ligne', () async {
    const repository = NaveRepository();
    const expected = {
      'amour': 'Amour',
      'foi': 'Foi',
      'grâce': 'Grâce de Dieu',
      'péché': 'Péché',
      'salut': 'Salut',
      'prière': 'Prière',
      'Dieu': 'Dieu',
      'Jésus': 'Jésus-Christ',
      'Saint-Esprit': 'Saint-Esprit',
      'Adam': 'Adam',
      'alliance': 'Alliance',
      'royaume': 'Royaume des cieux',
      'église': 'Église',
      'repentance': 'Repentance',
      'justification': 'Justification',
      'sanctification': 'Sanctification',
      'Abraham': 'Abraham',
      'Moïse': 'Moïse',
      'David': 'David',
      'Paul': 'Paul',
      'Pierre': 'Pierre',
    };

    for (final entry in expected.entries) {
      final results = await repository.search(entry.key);
      expect(results, isNotEmpty, reason: 'Recherche Nave : ${entry.key}');
      expect(results.first.title, entry.value, reason: entry.key);
      expect(results.first.titleEnglish, isNotEmpty);
    }
  });

  test('normalise casse, accents, traits d’union et pluriels simples',
      () async {
    const repository = NaveRepository();
    const groups = {
      'Amour': ['amour', 'AMOUR', 'Amour'],
      'Foi': ['foi', 'FOI', 'Foi'],
      'Grâce de Dieu': ['GRACE', 'Grace', 'grâce', 'grace', 'grâces'],
      'Salut': ['salut', 'SALUT', 'Salut'],
      'Prière': ['prière', 'PRIERE', 'priere'],
      'Péché': ['péché', 'PECHE', 'peche'],
      'Jésus-Christ': ['JESUS', 'Jesus', 'Jésus'],
      'Église': ['EGLISE', 'eglise', 'Église', 'églises'],
      'Saint-Esprit': [
        'SAINT ESPRIT',
        'Saint-Esprit',
        'Esprit Saint',
        'Holy Spirit',
      ],
      'Écritures': ['Ecriture', 'Écriture', 'Ecritures', 'Écritures'],
      'Moïse': ['MOISE', 'Moise', 'Moïse'],
    };
    for (final group in groups.entries) {
      for (final query in group.value) {
        expect(
          (await repository.search(query)).first.title,
          group.key,
          reason: query,
        );
      }
    }
  });

  test('la langue anglaise conserve et recherche les titres originaux',
      () async {
    const repository = NaveRepository();
    expect(
      (await repository.search('LOVE', language: AppLanguage.en)).first.title,
      'LOVE',
    );
    expect(
      (await repository.search('CHURCH', language: AppLanguage.en)).first.title,
      'CHURCH',
    );
  });

  test('une entrée française absente se replie sur l’anglais', () async {
    const repository = NaveRepository();
    final result = (await repository.search('AARON')).first;
    expect(result.title, 'AARON');
    expect(result.titleEnglish, 'AARON');
    expect(result.isTranslated, isFalse);
  });

  test('détails français, sections et références restent liés au cœur Nave',
      () async {
    const repository = NaveRepository();
    final god = (await repository.search('Dieu')).first;
    final references = await repository.references(god.id);
    expect(references, isNotEmpty);
    final sections = references.map((reference) => reference.subtopic).toSet();
    expect(
      sections,
      containsAll([
        'À Adam',
        'À Abraham',
        'À Jacob, à Béthel',
        'À Moïse, dans le buisson ardent',
        'À Moïse, au Sinaï',
        'À Moïse et Josué',
        'À Israël',
        'À Gédéon',
        'À Salomon',
        'À Ésaïe',
        'À Ézéchiel',
        'Proclamé',
      ]),
    );
    expect(references.every((reference) => reference.bookId > 0), isTrue);
    expect(references.every((reference) => reference.chapter > 0), isTrue);
    expect(references.every((reference) => reference.verseStart > 0), isTrue);
  });

  test('les dix thèmes doctrinaux majeurs gardent français, anglais et liens',
      () async {
    const repository = NaveRepository();
    const expected = {
      'Amour': 'LOVE',
      'Foi': 'FAITH',
      'Grâce': 'GRACE OF GOD',
      'Dieu': 'GOD',
      'Jésus': 'JESUS, THE CHRIST',
      'Saint-Esprit': 'HOLY SPIRIT',
      'Prière': 'PRAYER',
      'Salut': 'SALVATION',
      'Alliance': 'COVENANT',
      'Église': 'CHURCH',
    };
    for (final entry in expected.entries) {
      final topic = (await repository.search(entry.key)).first;
      expect(topic.titleEnglish, entry.value, reason: entry.key);
      expect(topic.isTranslated, isTrue, reason: entry.key);
      expect(topic.translationStatus, 'manual', reason: entry.key);
      final references = await repository.references(topic.id);
      expect(references, isNotEmpty, reason: entry.key);
      expect(
        references.every((reference) => reference.subtopicEnglish.isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
  });

  test('le catalogue français est trié sur le libellé affiché', () async {
    const repository = NaveRepository();
    final topics = await repository.browse(limit: 6000);
    final normalized = topics.map((topic) => repository.normalize(topic.title));
    expect(normalized, orderedEquals([...normalized]..sort()));
  });

  test('les thèmes liés à un verset utilisent aussi la couche localisée',
      () async {
    const repository = NaveRepository();
    final linkedTopics = await repository.forVerse(1, 1, 1);
    expect(linkedTopics, isNotEmpty);
    expect(
        linkedTopics.every((topic) => topic.titleEnglish.isNotEmpty), isTrue);
    expect(
      linkedTopics.map((topic) => topic.titleEnglish),
      containsAll([
        'CREATION',
        'EARTH',
        'GOD',
        'HEAVEN',
        'JESUS, THE CHRIST',
        'MIRACLES',
        'TIME',
      ]),
    );
  });

  test('le corpus V2 couvre les thèmes et personnes réellement présents',
      () async {
    const repository = NaveRepository();
    const expected = {
      'Trinité': 'TRINITY',
      'Loi': 'LAW',
      'Louange': 'PRAISE',
      'Sainteté': 'HOLINESS',
      'Justice': 'JUSTICE',
      'Jugement': 'JUDGMENT',
      'Mission': 'MISSIONS',
      'Famille': 'FAMILY',
      'Enfant': 'CHILDREN',
      'Sagesse': 'WISDOM',
      'Obéissance': 'OBEDIENCE',
      'Souffrance': 'SUFFERING',
      'Persécution': 'PERSECUTION',
      'Pasteur': 'PASTOR',
      'Serviteur': 'SERVANT',
      'Offrande': 'OFFERINGS',
      'Dîme': 'TITHES',
      'Miracle': 'MIRACLES',
      'Guérison': 'CURES',
      'Promesse': 'PROMISES',
      'Ève': 'EVE',
      'Noé': 'NOAH',
      'Isaac': 'ISAAC',
      'Jacob': 'JACOB',
      'Josué': 'JOSHUA',
      'Salomon': 'SOLOMON',
      'Élie': 'ELIJAH',
      'Élisée': 'ELISHA',
      'Ésaïe': 'ISAIAH',
      'Jérémie': 'JEREMIAH',
      'Daniel': 'DANIEL',
    };
    for (final entry in expected.entries) {
      final result = (await repository.search(entry.key)).first;
      expect(result.titleEnglish, entry.value, reason: entry.key);
      expect(result.translationStatus, 'manual', reason: entry.key);
    }
  });

  test('les aperçus Nave suivent chacune des cinq versions installées',
      () async {
    const repository = NaveRepository();
    final grace = (await repository.search('Grâce')).first;
    final versions = await BibleVersionRepository.getInstalledVersions();
    expect(versions.map((version) => version.abbreviation),
        containsAll(['LSG', 'DARBY', 'OST', 'NCL', 'MAR']));
    for (final version in versions) {
      await BibleVersionRepository.setActiveVersion(version.id);
      final references = await repository.references(grace.id);
      expect(references, isNotEmpty, reason: version.abbreviation);
      expect(references.first.verseText, isNotEmpty,
          reason: version.abbreviation);
      expect(references.first.versionAbbreviation, version.abbreviation,
          reason: version.abbreviation);
      expect(references.first.versionId, version.id,
          reason: version.abbreviation);
    }
  });
}
