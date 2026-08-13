import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
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
    'valide le parcours réel des trois Bibles publiées',
    () async {
      HttpOverrides.global = null;
      const manager = ResourceManager();
      const ids = [
        OfflineResourceId.darby,
        OfflineResourceId.ostervald,
        OfflineResourceId.neoCrampon,
      ];

      Future<void> removeAll() async {
        for (final id in ids) {
          await manager.remove(id);
        }
      }

      await removeAll();
      addTearDown(() async {
        HttpOverrides.global = null;
        await removeAll();
      });

      final catalog = await manager.resolvedCatalog();
      for (final id in ids) {
        final resource = catalog.singleWhere((entry) => entry.id == id);
        expect(resource.downloadUrl, startsWith('https://github.com/'));
        expect(resource.canDownload, isTrue);
        expect(await manager.state(id), OfflineResourceState.notInstalled);

        final target = await manager.installedFile(resource);
        var progressEvents = 0;
        var partSeen = false;
        var lastReceived = 0;
        await manager.download(
          id,
          onProgress: (received, total) {
            progressEvents++;
            lastReceived = received;
            partSeen = partSeen || File('${target.path}.part').existsSync();
            expect(total, resource.sizeBytes);
          },
        );

        expect(progressEvents, greaterThan(0));
        expect(lastReceived, resource.sizeBytes);
        expect(partSeen, isTrue);
        expect(await File('${target.path}.part').exists(), isFalse);
        expect(await target.length(), resource.sizeBytes);
        expect(await manager.state(id), OfflineResourceState.installed);
        await ResourceManager.validateSqliteFile(target.path);
      }

      final installed = await BibleVersionRepository.getInstalledVersions();
      expect(
        installed.map((version) => version.abbreviation).toSet(),
        {'LSG', 'DARBY', 'OST', 'NCL'},
      );

      final core = await DatabaseService.database;
      final john = await core.query(
        'books',
        columns: ['id'],
        where: 'abbreviation = ?',
        whereArgs: ['JHN'],
        limit: 1,
      );
      final johnId = john.single['id'] as int;
      final john316 = <String, String>{};
      for (final version in installed) {
        final verse = await BibleVersionRepository.getVerse(
          bookId: johnId,
          chapterNumber: 3,
          verseNumber: 16,
          versionId: version.id,
        );
        john316[version.abbreviation] = verse!['text'] as String;
      }
      expect(john316.keys, {'LSG', 'DARBY', 'OST', 'NCL'});
      expect(john316.values.toSet(), hasLength(4));

      HttpOverrides.global = _OfflineHttpOverrides();
      for (final version in installed) {
        final chapter = await BibleVersionRepository.getChapter(
          bookId: johnId,
          chapterNumber: 3,
          versionId: version.id,
        );
        expect(chapter, isNotEmpty);
      }

      final darby = installed.singleWhere(
        (version) => version.abbreviation == 'DARBY',
      );
      await BibleVersionRepository.setActiveVersion(darby.id);
      await manager.remove(OfflineResourceId.darby);
      final withoutDarby = await BibleVersionRepository.getInstalledVersions();
      expect(
        withoutDarby.map((version) => version.abbreviation),
        isNot(contains('DARBY')),
      );
      final fallbackId =
          await BibleVersionRepository.getSelectedVersionId(withoutDarby);
      expect(
        withoutDarby
            .singleWhere((version) => version.id == fallbackId)
            .isDefault,
        isTrue,
      );

      HttpOverrides.global = null;
      await manager.download(OfflineResourceId.darby);
      expect(
        (await BibleVersionRepository.getInstalledVersions())
            .map((version) => version.abbreviation),
        contains('DARBY'),
      );
    },
    skip: !_runRealReleaseTests,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('Réseau volontairement désactivé');
  }
}
