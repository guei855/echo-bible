import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
import 'package:flutter/material.dart';
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

  test('conserve seulement la LSG embarquée', () async {
    const manager = ResourceManager();
    expect(
      await manager.state(OfflineResourceId.lsg),
      OfflineResourceState.installed,
    );
    expect(
      await manager.state(OfflineResourceId.strong),
      OfflineResourceState.notInstalled,
    );
    expect(
      await manager.state(OfflineResourceId.paroleDeVie),
      OfflineResourceState.licenseRequired,
    );
  });

  test('une URL HTTPS validée dans le manifeste rend Darby téléchargeable',
      () async {
    final directory = await Directory.systemTemp.createTemp('echo-manifest-');
    addTearDown(() => directory.delete(recursive: true));
    final descriptor =
        const ResourceManager().descriptor(OfflineResourceId.darby);
    final manager = ResourceManager(
      rootDirectory: directory,
      manifestOverrides: {
        'darby': {
          'id': 'darby',
          'status': 'available',
          'version': descriptor.version,
          'sizeBytes': descriptor.sizeBytes,
          'sha256': descriptor.sha256,
          'localFileName': descriptor.localFileName,
          'downloadUrl':
              'https://github.com/example/echo-bible/releases/download/v1.0.0-resources/darby.db',
        },
      },
    );
    final resolved = (await manager.resolvedCatalog())
        .firstWhere((resource) => resource.id == OfflineResourceId.darby);
    expect(resolved.canDownload, isTrue);
    expect(await manager.state(OfflineResourceId.darby),
        OfflineResourceState.notInstalled);
  });

  test('valide les quatre modules bibliques SQLite', () async {
    for (final name in [
      'darby.db',
      'ostervald.db',
      'neo_crampon.db',
      'martin.db',
    ]) {
      await ResourceManager.validateSqliteFile(
        File('release_resources/fr/bibles/$name').absolute.path,
      );
    }
  });

  test('Martin respecte le canon biblique complet', () async {
    final database = await databaseFactory.openDatabase(
      File('release_resources/fr/bibles/martin.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    addTearDown(database.close);

    final integrity = await database.rawQuery('PRAGMA integrity_check');
    final bookCount = (await database.rawQuery(
      'SELECT COUNT(*) AS total FROM books',
    ))
        .single['total'];
    final chapterCount = (await database.rawQuery(
      'SELECT COUNT(*) AS total FROM chapters',
    ))
        .single['total'];
    final verseCount = (await database.rawQuery(
      'SELECT COUNT(*) AS total FROM verses',
    ))
        .single['total'];
    final canonicalBounds = await database.rawQuery(
      'SELECT MIN(canonical_number) AS first, '
      'MAX(canonical_number) AS last, '
      'COUNT(DISTINCT canonical_number) AS total FROM books',
    );

    expect(integrity.single.values.single, 'ok');
    expect(bookCount, 66);
    expect(chapterCount, 1189);
    expect(verseCount, 31057);
    expect(canonicalBounds.single, {'first': 1, 'last': 66, 'total': 66});
  });

  test('refuse une base SQLite corrompue', () async {
    final directory = await Directory.systemTemp.createTemp('echo-corrupt-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/corrupt.db');
    await file.writeAsString('not sqlite');
    expect(
      () => ResourceManager.validateSqliteFile(file.path),
      throwsA(anything),
    );
  });

  test('installe puis désinstalle les quatre Bibles téléchargeables', () async {
    final directory = await Directory.systemTemp.createTemp('echo-install-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(rootDirectory: directory);
    const modules = {
      OfflineResourceId.darby: 'darby.db',
      OfflineResourceId.ostervald: 'ostervald.db',
      OfflineResourceId.neoCrampon: 'neo_crampon.db',
      OfflineResourceId.martin: 'martin.db',
    };
    for (final entry in modules.entries) {
      await manager.installFromFile(
        entry.key,
        File('release_resources/fr/bibles/${entry.value}'),
      );
      expect(await manager.state(entry.key), OfflineResourceState.installed);
      final installed =
          await manager.installedFile(manager.descriptor(entry.key));
      expect(await installed.exists(), isTrue);
      await manager.remove(entry.key);
      expect(await manager.state(entry.key), OfflineResourceState.notInstalled);
    }
  });

  test('installe, supprime et réinstalle les modules d’étude', () async {
    final directory = await Directory.systemTemp.createTemp('echo-nave-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(rootDirectory: directory);
    const modules = {
      OfflineResourceId.strong: 'common/strong/strong.db',
      OfflineResourceId.nave: 'en/nave/nave_core.db',
      OfflineResourceId.naveFrench: 'fr/nave/nave_fr.db',
      OfflineResourceId.crossReferences:
          'common/cross_references/cross_references.db',
    };
    for (final entry in modules.entries) {
      final source = File('release_resources/${entry.value}');
      await manager.installFromFile(entry.key, source);
      expect(await manager.state(entry.key), OfflineResourceState.installed);
      await manager.remove(entry.key);
      final installed =
          await manager.installedFile(manager.descriptor(entry.key));
      expect(await installed.exists(), isFalse);
      await manager.installFromFile(entry.key, source);
      expect(await manager.state(entry.key), OfflineResourceState.installed);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('télécharge réellement les modules d’étude puis reste offline',
      () async {
    final sources = <OfflineResourceId, File>{
      OfflineResourceId.nave: File('release_resources/en/nave/nave_core.db'),
      OfflineResourceId.naveFrench:
          File('release_resources/fr/nave/nave_fr.db'),
      OfflineResourceId.crossReferences: File(
        'release_resources/common/cross_references/cross_references.db',
      ),
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final fileName = request.uri.pathSegments.last;
      final id = sources.keys.firstWhere(
        (candidate) =>
            const ResourceManager().descriptor(candidate).localFileName ==
            fileName,
      );
      final source = sources[id]!;
      request.response.contentLength = await source.length();
      await request.response.addStream(source.openRead());
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('echo-nave-http-');
    addTearDown(() => directory.delete(recursive: true));
    final defaults = const ResourceManager();
    final manager = ResourceManager(
      rootDirectory: directory,
      resourceOverrides: {
        for (final id in sources.keys)
          id: _withUrl(
            defaults.descriptor(id),
            'http://${server.address.address}:${server.port}/'
            '${defaults.descriptor(id).localFileName}',
          ),
      },
    );
    for (final id in sources.keys) {
      await _withRealHttp(() => manager.download(id));
      expect(await manager.state(id), OfflineResourceState.installed);
    }
    await server.close(force: true);
    for (final id in sources.keys) {
      final installed = await manager.installedFile(manager.descriptor(id));
      await ResourceManager.validateSqliteFile(installed.path);
    }
  });

  test('refuse un checksum invalide sans remplacer le module', () async {
    final directory = await Directory.systemTemp.createTemp('echo-checksum-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('release_resources/fr/bibles/darby.db');
    final invalid = File('${directory.path}/invalid.db');
    await source.copy(invalid.path);
    final handle = await invalid.open(mode: FileMode.append);
    await handle.writeByte(0);
    await handle.close();
    final manager = ResourceManager(rootDirectory: directory);
    expect(
      () => manager.installFromFile(OfflineResourceId.darby, invalid),
      throwsA(isA<ResourceDownloadException>()),
    );
    final installed = await manager
        .installedFile(manager.descriptor(OfflineResourceId.darby));
    expect(await installed.exists(), isFalse);
  });

  test('télécharge et installe Darby depuis une URL HTTP de test', () async {
    final source = File('release_resources/fr/bibles/darby.db');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.contentLength = await source.length();
      await request.response.addStream(source.openRead());
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('echo-http-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(
      rootDirectory: directory,
      resourceOverrides: {
        OfflineResourceId.darby: _withUrl(
          const ResourceManager().descriptor(OfflineResourceId.darby),
          'http://${server.address.address}:${server.port}/darby.db',
        ),
      },
    );
    await _withRealHttp(() => manager.download(OfflineResourceId.darby));
    expect(await manager.state(OfflineResourceId.darby),
        OfflineResourceState.installed);
  });

  test('nettoie le fichier temporaire si le téléchargement est interrompu',
      () async {
    final source = File('release_resources/fr/bibles/darby.db');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.contentLength = await source.length();
      await request.response.addStream(source.openRead());
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('echo-cancel-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(
      rootDirectory: directory,
      resourceOverrides: {
        OfflineResourceId.darby: _withUrl(
          const ResourceManager().descriptor(OfflineResourceId.darby),
          'http://${server.address.address}:${server.port}/darby.db',
        ),
      },
    );
    final future = _withRealHttp(
      () => manager.download(
        OfflineResourceId.darby,
        onProgress: (_, __) => manager.cancel(OfflineResourceId.darby),
      ),
    );
    await expectLater(future, throwsA(anything));
    final target = await manager
        .installedFile(manager.descriptor(OfflineResourceId.darby));
    expect(await File('${target.path}.part').exists(), isFalse);
    expect(await target.exists(), isFalse);
  });

  test('signale une URL indisponible sans créer de module', () async {
    final closedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = closedServer.port;
    await closedServer.close(force: true);
    final directory = await Directory.systemTemp.createTemp('echo-url-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(
      rootDirectory: directory,
      resourceOverrides: {
        OfflineResourceId.darby: _withUrl(
          const ResourceManager().descriptor(OfflineResourceId.darby),
          'http://127.0.0.1:$port/darby.db',
        ),
      },
    );
    await expectLater(
      _withRealHttp(() => manager.download(OfflineResourceId.darby)),
      throwsA(anything),
    );
  });

  testWidgets('carte dictionnaire lisible sur petit écran sombre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const manager = ResourceManager();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ResourceInstallCard(
            resource: manager.descriptor(OfflineResourceId.dictionary),
            state: OfflineResourceState.preparing,
            onLater: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Dictionnaire biblique français'), findsOneWidget);
    expect(find.textContaining('Ressource en préparation'), findsWidgets);
  });

  testWidgets('état non installé propose réellement Télécharger', (
    tester,
  ) async {
    const manager = ResourceManager();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceInstallCard(
            resource: manager.descriptor(OfflineResourceId.dictionary),
            state: OfflineResourceState.notInstalled,
            onDownload: () {},
            onLater: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('resource-status')), findsOneWidget);
    expect(find.text('Télécharger'), findsOneWidget);
  });
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

Future<T> _withRealHttp<T>(Future<T> Function() action) async {
  HttpOverrides.global = null;
  return action();
}
