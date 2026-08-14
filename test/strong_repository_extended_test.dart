import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/repositories/strong_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('distingue H9003 des Strong classiques sans conversion', () async {
    const repository = StrongRepository();
    final extended = await repository.findByNumber('H9003');
    final paddedClassic = await repository.findByNumber('H0430');
    final greekLove = await repository.findByNumber('G26');
    final paddedGreekLove = await repository.findByNumber('G0026');
    final greekWord = await repository.findByNumber('G3056');
    final hebrewBeginning = await repository.findByNumber('H7225');

    expect(extended, isNotNull);
    expect(extended!.strongNumber, 'H9003');
    expect(extended.originalWord, '/ב');
    expect(extended.morphology, 'Prefix');
    expect(extended.numberKind, StrongNumberKind.extendedGrammar);

    expect(paddedClassic?.strongNumber, 'H430');
    expect(paddedClassic?.numberKind, StrongNumberKind.classic);
    expect(greekLove?.strongNumber, 'G26');
    expect(paddedGreekLove?.strongNumber, 'G26');
    expect(greekWord?.strongNumber, 'G3056');
    expect(greekWord?.originalWord, isNot('λογος'));
    expect(greekWord?.transliteration, 'logos');
    expect(hebrewBeginning?.strongNumber, 'H7225');

    final occurrences = await repository.occurrences('H9003', limit: 5);
    expect(occurrences, isNotEmpty);
    expect(occurrences.every((item) => item.strongNumber == 'H9003'), isTrue);
  });

  test('recherche les codes ambigus et les mots français réels', () async {
    const repository = StrongRepository();
    final ambiguous = await repository.search('26');
    expect(ambiguous.map((entry) => entry.strongNumber),
        containsAll(['H26', 'G26']));

    for (final query in [
      'logos',
      'agape',
      'Dieu',
      'commencement',
      'amour',
      'grâce',
      'salut',
      'péché',
      'Parole'
    ]) {
      final results = await repository.search(query);
      expect(results, isNotEmpty, reason: query);
    }
    expect(
      (await repository.search('commencement'))
          .map((entry) => entry.strongNumber),
      contains('H7225'),
    );
    expect(
      (await repository.search('Parole')).map((entry) => entry.strongNumber),
      contains('G3056'),
    );
    expect(
      (await repository.search('logos')).map((entry) => entry.strongNumber),
      contains('G3056'),
    );
    expect(
      (await repository.search('agape')).map((entry) => entry.strongNumber),
      contains('G26'),
    );
    expect(
      (await repository.search('λόγος')).map((entry) => entry.strongNumber),
      contains('G3056'),
    );
  });

  test('recherche la forme hébraïque avec ou sans signes massorétiques',
      () async {
    const repository = StrongRepository();
    final pointed = await repository.search('אֱלֹהִים');
    final unpointed = await repository.search('אלהים');

    expect(pointed.map((entry) => entry.strongNumber), contains('H430'));
    expect(unpointed.map((entry) => entry.strongNumber), contains('H430'));
  });

  test('lit la morphologie et pagine les occurrences depuis strong.db',
      () async {
    const repository = StrongRepository();
    final description = await repository.morphologyDescription('N-NSM');
    final first = await repository.occurrences('G3056', limit: 30);
    final second = await repository.occurrences(
      'G3056',
      limit: 30,
      offset: 30,
    );

    expect(description, isNotEmpty);
    expect(first.length, 30);
    expect(second, isNotEmpty);
    expect(first.first.originalToken, isNotEmpty);
    expect(first.first.morphologyDescription, isNotEmpty);
  });

  test('conserve les associations multiples et les termes non traduits',
      () async {
    const repository = StrongRepository();
    final genesisOneFour = await repository.frenchForVerse(1, 1, 4);
    expect(
      genesisOneFour.any(
        (token) => !token.isTranslated && token.strongNumber == 'H996',
      ),
      isTrue,
    );
    final johnThreeSixteen = await repository.frenchForVerse(43, 3, 16);
    final son = johnThreeSixteen.where((token) => token.surface == 'son');
    expect(
        son.map((token) => token.strongNumber), containsAll(['G3588', 'G846']));
  });
}
