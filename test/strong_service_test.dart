import 'package:echo_bible/features/bible/services/strong_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('retrouve les entrées Tyndale hébraïques et grecques', () async {
    final hebrew = await StrongService.search('H430');
    final paddedHebrew = await StrongService.search('H0430');
    final greek = await StrongService.search('G26');
    final paddedGreek = await StrongService.search('G0026');
    final h3588 = await StrongService.search('H3588');
    final h7225 = await StrongService.search('H7225');
    final g3056 = await StrongService.search('G3056');

    expect(hebrew, isNotEmpty);
    expect(hebrew.first.code, 'H430');
    expect(hebrew.first.source, 'TBESH');
    expect(paddedHebrew.first.code, 'H430');
    expect(hebrew.first.language, 'Hébreu');

    expect(greek, isNotEmpty);
    expect(greek.first.code, 'G26');
    expect(greek.first.source, 'TBESG');
    expect(paddedGreek.first.code, 'G26');
    expect(greek.first.language, 'Grec');
    expect(greek.first.definition, isNotEmpty);

    expect(h3588, isNotEmpty);
    expect(h3588.first.code, startsWith('H3588'));
    expect(h3588.first.transliteration, 'ki');
    expect(h3588.first.definition, isNull);

    expect(h7225, isNotEmpty);
    expect(h7225.first.code, 'H7225');
    expect(h7225.first.lemma, 'רֵאשִׁית');

    expect(g3056, isNotEmpty);
    expect(g3056.first.code, 'G3056');
    expect(g3056.first.transliteration, 'logos');
    expect(g3056.first.definition, isNotEmpty);
  });
}
