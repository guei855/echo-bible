import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/services/dictionary_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('normalise casse, accents et ligatures françaises', () {
    expect(DictionaryRepository.normalizeSearchTerm('GRÂCE'), 'grace');
    expect(DictionaryRepository.normalizeSearchTerm('Jérusalem'), 'jerusalem');
    expect(DictionaryRepository.normalizeSearchTerm('Moïse'), 'moise');
    expect(DictionaryRepository.normalizeSearchTerm('Œuvre'), 'oeuvre');
  });

  test('DB absente et corrompue restent indisponibles sans erreur', () async {
    final root = await Directory.systemTemp.createTemp('echo-dictionary-');
    addTearDown(() => root.delete(recursive: true));
    final manager = ResourceManager(rootDirectory: root);
    final repository = DictionaryRepository(
      databaseService: DictionaryDatabaseService(resourceManager: manager),
    );
    expect(await repository.isAvailable(), isFalse);
    final file = await manager.installedFile(
      manager.descriptor(OfflineResourceId.dictionary),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('not sqlite');
    expect(await repository.isAvailable(), isFalse);
    expect(await repository.search('Abraham'), isEmpty);
  });

  test('base réelle: ordre exact, alias, préfixe et contenu', () async {
    final root = await Directory.systemTemp.createTemp('echo-dictionary-db-');
    addTearDown(() => root.delete(recursive: true));
    final manager = ResourceManager(rootDirectory: root);
    final target = await manager.installedFile(
      manager.descriptor(OfflineResourceId.dictionary),
    );
    await target.parent.create(recursive: true);
    await File(
      'release_resources/fr/dictionaries/vigouroux_dictionary.db',
    ).copy(target.path);
    final repository = DictionaryRepository(
      databaseService: DictionaryDatabaseService(resourceManager: manager),
    );

    expect(await repository.isAvailable(), isTrue);
    expect((await repository.search('grâce')).first.headword, 'Grâce');
    expect((await repository.search('Alliance')).first.headword, 'Alliances');
    expect((await repository.search('pharisien')).first.headword, 'Pharisiens');
    expect((await repository.search('JERUSALEM')).first.headword, 'Jérusalem');
    expect((await repository.search('Moise')).first.headword, 'Moïse');
    expect(await repository.search('Providentissimus'), isNotEmpty);
    expect(await repository.listAlphabetically(letter: 'A'), isNotEmpty);
  });
}
