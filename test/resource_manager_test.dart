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
      OfflineResourceState.readyForHosting,
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

  test('valide les trois modules bibliques SQLite', () async {
    for (final name in ['darby.db', 'ostervald.db', 'neo_crampon.db']) {
      await ResourceManager.validateSqliteFile(
        File('release_resources/fr/bibles/$name').absolute.path,
      );
    }
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

  test('installe puis désinstalle Darby, Ostervald et Néo-Crampon', () async {
    final directory = await Directory.systemTemp.createTemp('echo-install-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = ResourceManager(rootDirectory: directory);
    const modules = {
      OfflineResourceId.darby: 'darby.db',
      OfflineResourceId.ostervald: 'ostervald.db',
      OfflineResourceId.neoCrampon: 'neo_crampon.db',
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
