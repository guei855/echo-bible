import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/services/dictionary_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _runRealReleaseTests = bool.fromEnvironment('REAL_RELEASE_TESTS');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'télécharge, utilise hors ligne, supprime et réinstalle Vigouroux',
    () async {
      HttpOverrides.global = null;
      final root = await Directory.systemTemp.createTemp('echo-vigouroux-');
      addTearDown(() => root.delete(recursive: true));
      final descriptor =
          const ResourceManager().descriptor(OfflineResourceId.dictionary);
      final manager = ResourceManager(
        rootDirectory: root,
        resourceOverrides: {
          OfflineResourceId.dictionary: _withUrl(
            descriptor,
            'https://github.com/guei855/echo-bible/releases/download/'
            'v1.1.0-resources/vigouroux_dictionary.db',
          ),
        },
      );
      final repository = DictionaryRepository(
        databaseService: DictionaryDatabaseService(resourceManager: manager),
      );

      expect(await repository.isAvailable(), isFalse);
      await manager.download(OfflineResourceId.dictionary);
      expect(await repository.isAvailable(), isTrue);
      for (final query in [
        'Abraham',
        'Alliance',
        'GRACE',
        'grâce',
        'Justification',
        'Pharisien',
        'Sanhédrin',
        'Temple',
        'JERUSALEM',
        'Jérusalem',
        'moise',
        'Moïse',
      ]) {
        expect(await repository.search(query), isNotEmpty, reason: query);
      }

      HttpOverrides.global = _OfflineHttpOverrides();
      expect((await repository.search('Temple')).first.headword, 'Temple');
      await manager.remove(OfflineResourceId.dictionary);
      expect(await repository.isAvailable(), isFalse);
      expect(await repository.search('Temple'), isEmpty);

      HttpOverrides.global = null;
      await manager.download(OfflineResourceId.dictionary);
      expect((await repository.search('Moïse')).first.headword, 'Moïse');
    },
    skip: !_runRealReleaseTests,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

ResourceDescriptor _withUrl(ResourceDescriptor source, String url) =>
    ResourceDescriptor(
      id: source.id,
      name: source.name,
      shortName: source.shortName,
      language: source.language,
      category: source.category,
      description: source.description,
      version: source.version,
      sizeBytes: source.sizeBytes,
      downloadUrl: url,
      sha256: source.sha256,
      license: source.license,
      source: source.source,
      sourceUrl: source.sourceUrl,
      localFileName: source.localFileName,
    );

class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('Réseau volontairement désactivé');
  }
}
