import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('recherche Nave en français et en anglais', () async {
    const repository = NaveRepository();
    const queries = [
      'amour',
      'love',
      'foi',
      'faith',
      'grâce',
      'péché',
      'salut',
      'prière',
      'Adam',
      'Jésus',
    ];

    for (final query in queries) {
      final results = await repository.search(query);
      expect(results, isNotEmpty, reason: 'Recherche Nave : $query');
    }

    expect((await repository.search('amour')).first.title, 'Amour');
    expect((await repository.search('foi')).first.title, 'Foi');
    expect((await repository.search('péché')).first.title, 'Péché');
    expect((await repository.search('Jésus')).first.title, 'Jésus-Christ');

    final linkedTopics = await repository.forVerse(1, 1, 1);
    expect(linkedTopics, isNotEmpty);

    final god = (await repository.search('Dieu')).first;
    final sections = (await repository.references(god.id))
        .map((reference) => reference.subtopic)
        .toSet();
    // La couche FR est partielle : les sections non relues utilisent le
    // repli anglais sans dupliquer les références du module central.
    expect(sections, contains('To Adam'));
    expect(sections, contains('To Abraham'));
    expect(sections, contains('To Jacob, at Beth-el'));
    expect(sections, contains('To Moses, in the flaming bush'));
    expect(sections, contains('To Moses, at Sinai'));
    expect(sections, contains('To Moses and Joshua'));
    expect(sections, contains('To Israel'));
    expect(sections, contains('To Gideon'));
    expect(sections, contains('To Solomon'));
    expect(sections, contains('To Isaiah'));
    expect(sections, contains('To Ezekiel'));
    expect(sections, contains('Proclaimed'));
  });
}
