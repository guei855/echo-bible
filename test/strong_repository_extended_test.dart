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
    final greekWord = await repository.findByNumber('G3056');

    expect(extended, isNotNull);
    expect(extended!.strongNumber, 'H9003');
    expect(extended.originalWord, '/ב');
    expect(extended.morphology, 'Prefix');
    expect(extended.numberKind, StrongNumberKind.extendedGrammar);

    expect(paddedClassic?.strongNumber, 'H430');
    expect(paddedClassic?.numberKind, StrongNumberKind.classic);
    expect(greekLove?.strongNumber, 'G26');
    expect(greekWord?.strongNumber, 'G3056');

    final occurrences = await repository.occurrences('H9003', limit: 5);
    expect(occurrences, isNotEmpty);
    expect(occurrences.every((item) => item.strongNumber == 'H9003'), isTrue);
  });
}
