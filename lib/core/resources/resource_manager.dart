import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

typedef DownloadProgress = void Function(int received, int total);

class ResourceManager {
  static final Map<OfflineResourceId, Future<void> Function()>
      _releaseHandlers = {};

  static void registerReleaseHandler(
    OfflineResourceId id,
    Future<void> Function() handler,
  ) {
    _releaseHandlers[id] = handler;
  }

  final Map<OfflineResourceId, ResourceDescriptor>? resourceOverrides;
  final Map<String, Map<String, Object?>>? manifestOverrides;
  final Directory? rootDirectory;

  const ResourceManager({
    this.resourceOverrides,
    this.manifestOverrides,
    this.rootDirectory,
  });

  static final Map<OfflineResourceId, HttpClient> _downloads = {};
  static Future<Map<String, Map<String, Object?>>>? _manifestFuture;
  static const _releaseBase = String.fromEnvironment(
    'ECHO_BIBLE_RESOURCE_BASE_URL',
    defaultValue: '',
  );

  static const resources = <OfflineResourceId, ResourceDescriptor>{
    OfflineResourceId.lsg: ResourceDescriptor(
      id: OfflineResourceId.lsg,
      name: 'Louis Segond 1910',
      shortName: 'LSG',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Version française installée avec Echo Bible.',
      version: '2026-08-08',
      license: 'Domaine public',
      source: 'eBible.org',
      sourceUrl: 'https://ebible.org/bible/details.php?id=fraLSG',
      bundled: true,
      installedVersion: '2026-08-08',
      localFileName: 'bible.db',
    ),
    OfflineResourceId.darby: ResourceDescriptor(
      id: OfflineResourceId.darby,
      name: 'Bible J.N. Darby',
      shortName: 'JND',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Traduction littérale française.',
      version: '1.0.0',
      sizeBytes: 5574656,
      sha256:
          'e69c1cfc2e955966f5da3ddb294c05631e023da6eabbfa9785e2205bc4b8e66b',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/fr/bibles/darby.db',
      license: 'Domaine public',
      source: 'eBible.org / Bibles et Publications Chrétiennes',
      sourceUrl: 'https://ebible.org/bible/details.php?id=frajnd',
      localFileName: 'darby.db',
    ),
    OfflineResourceId.ostervald: ResourceDescriptor(
      id: OfflineResourceId.ostervald,
      name: 'Bible Ostervald',
      shortName: 'OST',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Bible française historique.',
      version: '1.0.0',
      sizeBytes: 5406720,
      sha256:
          '8217c359ea427c9a976dae62e0e11d3c0d5d70079d748b9203367b7912e9bff9',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/fr/bibles/ostervald.db',
      license: 'Domaine public',
      source: 'eBible.org',
      sourceUrl: 'https://ebible.org/bible/details.php?id=fra_fob',
      localFileName: 'ostervald.db',
    ),
    OfflineResourceId.neoCrampon: ResourceDescriptor(
      id: OfflineResourceId.neoCrampon,
      name: 'Sainte Bible néo-Crampon Libre',
      shortName: 'NCL',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Modernisation libre de la traduction Crampon.',
      version: '1.0.0',
      sizeBytes: 5509120,
      sha256:
          '35cc527276531fd49f124a59810b5fc0ec29d254a22cd58cb3f8580b9ed8f0ec',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/fr/bibles/neo_crampon.db',
      license: 'CC BY-SA 4.0',
      source: 'eBible.org / Fraternité de Tibériade',
      sourceUrl: 'https://ebible.org/bible/details.php?id=francl',
      localFileName: 'neo_crampon.db',
      copyrightHolder: 'Fraternité de Tibériade',
    ),
    OfflineResourceId.martin: ResourceDescriptor(
      id: OfflineResourceId.martin,
      name: 'Bible Martin',
      shortName: 'MAR',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Édition historique de David Martin, publiée en 1744.',
      version: '1.0.0',
      sizeBytes: 5656576,
      sha256:
          'c3e6e651e87ea6ae1c751b12526500606a3e387be351114f42cc22258e140256',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/fr/bibles/martin.db',
      license: 'Domaine public',
      source: 'GetBible / CrossWire Bible Society',
      sourceUrl:
          'https://www.crosswire.org/sword/modules/ModInfo.jsp?modName=FreBDM1744',
      localFileName: 'martin.db',
    ),
    OfflineResourceId.paroleDeVie: ResourceDescriptor(
      id: OfflineResourceId.paroleDeVie,
      name: 'Parole de Vie',
      shortName: 'PDV',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Autorisation explicite de l’éditeur nécessaire.',
      version: 'license-required',
      license: 'Tous droits réservés',
      source: 'Alliance biblique française',
      sourceUrl: 'https://www.alliancebiblique.fr/',
      localFileName: 'pdv.db',
      redistributionStatus: RedistributionStatus.licenseRequired,
    ),
    OfflineResourceId.francaisCourant: ResourceDescriptor(
      id: OfflineResourceId.francaisCourant,
      name: 'Bible en français courant',
      shortName: 'BFC',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Autorisation explicite de l’éditeur nécessaire.',
      version: 'license-required',
      license: 'Tous droits réservés',
      source: 'Alliance biblique française',
      sourceUrl: 'https://www.alliancebiblique.fr/',
      localFileName: 'bfc.db',
      redistributionStatus: RedistributionStatus.licenseRequired,
    ),
    OfflineResourceId.bibleAmplifiee: ResourceDescriptor(
      id: OfflineResourceId.bibleAmplifiee,
      name: 'Bible amplifiée française',
      shortName: 'AMP',
      language: ResourceLanguage.fr,
      category: ResourceCategory.bible,
      description: 'Aucune édition libre autorisée n’a été identifiée.',
      version: 'license-required',
      license: 'Autorisation éditeur nécessaire',
      source: 'Catalogue uniquement',
      sourceUrl: '',
      localFileName: 'amp_fr.db',
      redistributionStatus: RedistributionStatus.licenseRequired,
    ),
    OfflineResourceId.worldEnglishBible: ResourceDescriptor(
      id: OfflineResourceId.worldEnglishBible,
      name: 'World English Bible Classic',
      shortName: 'WEB',
      language: ResourceLanguage.en,
      category: ResourceCategory.bible,
      description:
          'Modern public-domain English Bible; module conversion pending.',
      version: '2020-stable',
      license: 'Public Domain (name is a trademark)',
      source: 'eBible.org',
      sourceUrl: 'https://ebible.org/bible/details.php?id=eng-web',
      localFileName: 'web.db',
    ),
    OfflineResourceId.strong: ResourceDescriptor(
      id: OfflineResourceId.strong,
      name: 'Lexique Strong hébreu et grec',
      shortName: 'Strong',
      language: ResourceLanguage.common,
      category: ResourceCategory.strong,
      description:
          'Lexique original, morphologie, occurrences et alignement français Segond 1910.',
      version: '2026-08-13-fr-strong-v1',
      sizeBytes: 133566464,
      sha256:
          'fce2edda296d09dd1ea3ce6e4be3663ef4ab1ce75744f8a53c4810c966af429b',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/common/strong/strong.db',
      license: 'STEP Bible CC BY 4.0 ; Segond 1910 domaine public',
      source: 'STEP Bible / Concordances et Traductions de la Bible',
      sourceUrl: 'https://concordance.bible/Sg1910/download/',
      localFileName: 'strong.db',
    ),
    OfflineResourceId.crossReferences: ResourceDescriptor(
      id: OfflineResourceId.crossReferences,
      name: 'Références croisées',
      shortName: 'XRefs',
      language: ResourceLanguage.common,
      category: ResourceCategory.crossReferences,
      description: 'Liens entre passages, lus dans la version active.',
      version: '2026-08-13',
      sizeBytes: 25624576,
      sha256:
          '76d61d3a42498b43e593f7fe7c6de8c6bdd646e3c11fa4659fee06a633ff9105',
      downloadUrl: _releaseBase == ''
          ? null
          : '$_releaseBase/common/cross_references/cross_references.db',
      license: 'CC BY 4.0',
      source: 'OpenBible.info',
      sourceUrl: 'https://www.openbible.info/labs/cross-references/',
      localFileName: 'cross_references.db',
    ),
    OfflineResourceId.nave: ResourceDescriptor(
      id: OfflineResourceId.nave,
      name: 'Nave — données originales',
      shortName: 'Nave EN',
      language: ResourceLanguage.en,
      category: ResourceCategory.nave,
      description: 'Index thématique original anglais et références.',
      version: '3.1',
      sizeBytes: 5758976,
      sha256:
          'a3376d1ea157118043c599e538b8df78e5e8280eef9911cc29a02fa3460b1314',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/en/nave/nave_core.db',
      license: 'Domaine public',
      source: 'Orville J. Nave / CCEL / CrossWire',
      sourceUrl: 'https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave',
      localFileName: 'nave_core.db',
    ),
    OfflineResourceId.naveFrench: ResourceDescriptor(
      id: OfflineResourceId.naveFrench,
      name: 'Nave — couche française',
      shortName: 'Nave FR',
      language: ResourceLanguage.fr,
      category: ResourceCategory.nave,
      description: 'Traductions françaises sans dupliquer les références.',
      version: '4',
      sizeBytes: 368640,
      sha256:
          '0e861ec435478995af836fcffa13241c606b86bff43eeae5bb1261e375a3dd19',
      downloadUrl:
          _releaseBase == '' ? null : '$_releaseBase/fr/nave/nave_fr.db',
      license: 'CC BY-SA 4.0 (couche de traduction française)',
      source: 'Echo Bible, d’après les entrées Nave',
      sourceUrl: 'https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave',
      localFileName: 'nave_fr.db',
    ),
    OfflineResourceId.dictionary: ResourceDescriptor(
      id: OfflineResourceId.dictionary,
      name: 'Dictionnaire biblique français',
      shortName: 'Vigouroux',
      language: ResourceLanguage.fr,
      category: ResourceCategory.dictionary,
      description: '786 articles français consultables entièrement hors ligne.',
      version: '1.0.0',
      sizeBytes: 9015296,
      sha256:
          '154b6617bbf5f52323952a79da09dc88a484de0170407818f7f8d5fdc6231928',
      license: 'Domaine public ; transcription Wikisource CC BY-SA 4.0',
      source: 'Dictionnaire de la Bible — F. Vigouroux / Gallica / Wikisource',
      sourceUrl: 'https://fr.wikisource.org/wiki/Dictionnaire_de_la_Bible',
      localFileName: 'vigouroux_dictionary.db',
    ),
    OfflineResourceId.commentaries: ResourceDescriptor(
      id: OfflineResourceId.commentaries,
      name: 'Commentaires bibliques français',
      shortName: 'Commentaires FR',
      language: ResourceLanguage.fr,
      category: ResourceCategory.commentary,
      description:
          'Les commentaires bibliques français ne sont pas encore installés.',
      version: 'preparing',
      license: 'Source et transcription à valider',
      source: 'Candidats du domaine public',
      sourceUrl: '',
      localFileName: 'commentaries_fr.db',
    ),
  };

  List<ResourceDescriptor> catalog({ResourceLanguage? language}) => resources
      .values
      .map((resource) => resourceOverrides?[resource.id] ?? resource)
      .where((resource) => language == null || resource.language == language)
      .toList(growable: false);

  Future<List<ResourceDescriptor>> resolvedCatalog({
    ResourceLanguage? language,
  }) async =>
      Future.wait(catalog(language: language).map(_resolveDescriptor));

  ResourceDescriptor descriptor(OfflineResourceId id) =>
      resourceOverrides?[id] ?? resources[id]!;

  Future<Directory> resourcesDirectory() async {
    if (rootDirectory != null) return rootDirectory!;
    const compileTimeFlutterTest = bool.fromEnvironment('FLUTTER_TEST');
    final isFlutterTest = compileTimeFlutterTest ||
        Platform.environment['FLUTTER_TEST']?.toLowerCase() == 'true';
    if (isFlutterTest) {
      return Directory(path.join(
        Directory.current.path,
        '.dart_localappdata',
        'echo_bible',
        'resources',
      ));
    }
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'echo_bible', 'resources'));
  }

  Future<File> installedFile(ResourceDescriptor resource) async {
    final root = await resourcesDirectory();
    return File(path.join(
      root.path,
      _categoryFolder(resource.category),
      resource.language.name,
      resource.localFileName,
    ));
  }

  Future<OfflineResourceState> state(OfflineResourceId id) async {
    final resource = await _resolveDescriptor(descriptor(id));
    if (resource.bundled) return OfflineResourceState.installed;
    if (resource.redistributionStatus == RedistributionStatus.licenseRequired) {
      return OfflineResourceState.licenseRequired;
    }
    if (resource.redistributionStatus == RedistributionStatus.unavailable) {
      return OfflineResourceState.unavailable;
    }
    final file = await installedFile(resource);
    if (!await file.exists()) {
      if (resource.canDownload) return OfflineResourceState.notInstalled;
      if (resource.readyForHosting) {
        return OfflineResourceState.readyForHosting;
      }
      return OfflineResourceState.preparing;
    }
    final preferences = await SharedPreferences.getInstance();
    final installed = preferences.getString('resource_${id.name}_version');
    return installed != null && installed != resource.version
        ? OfflineResourceState.updateAvailable
        : OfflineResourceState.installed;
  }

  Future<void> download(
    OfflineResourceId id, {
    DownloadProgress? onProgress,
  }) async {
    final resource = await _resolveDescriptor(descriptor(id));
    if (!resource.canDownload) throw const ResourceUnavailableException();
    final target = await installedFile(resource);
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.part');
    if (await temporary.exists()) await temporary.delete();
    final client = HttpClient();
    _downloads[id] = client;
    try {
      final request = await client.getUrl(Uri.parse(resource.downloadUrl!));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw ResourceDownloadException('HTTP ${response.statusCode}');
      }
      var received = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(received, resource.sizeBytes!);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received != resource.sizeBytes) {
        throw const ResourceDownloadException('Taille incorrecte');
      }
      await _verifyAndInstall(resource, temporary, target);
    } finally {
      client.close(force: true);
      _downloads.remove(id);
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Installs an already downloaded file through the exact same verification
  /// and atomic replacement path as an HTTP download.
  Future<void> installFromFile(OfflineResourceId id, File source) async {
    final resource = descriptor(id);
    if (resource.sha256 == null || resource.sizeBytes == null) {
      throw const ResourceUnavailableException();
    }
    final target = await installedFile(resource);
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.part');
    if (await temporary.exists()) await temporary.delete();
    try {
      await source.copy(temporary.path);
      await _verifyAndInstall(resource, temporary, target);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _verifyAndInstall(
    ResourceDescriptor resource,
    File temporary,
    File target,
  ) async {
    if (await temporary.length() != resource.sizeBytes) {
      throw const ResourceDownloadException('Taille incorrecte');
    }
    final digest = await sha256.bind(temporary.openRead()).first;
    if (digest.toString().toLowerCase() != resource.sha256!.toLowerCase()) {
      throw const ResourceDownloadException('Somme SHA-256 incorrecte');
    }
    if (path.extension(target.path).toLowerCase() == '.db') {
      await validateSqliteFile(temporary.path);
    }
    if (await target.exists()) {
      await _releaseHandlers[resource.id]?.call();
      await target.delete();
    }
    await temporary.rename(target.path);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'resource_${resource.id.name}_version',
      resource.version,
    );
  }

  void cancel(OfflineResourceId id) =>
      _downloads.remove(id)?.close(force: true);

  Future<void> remove(OfflineResourceId id) async {
    final resource = descriptor(id);
    if (resource.bundled) throw const ResourceBundledException();
    final file = await installedFile(resource);
    await _releaseHandlers[id]?.call();
    if (await file.exists()) await file.delete();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('resource_${id.name}_version');
  }

  static Future<void> validateSqliteFile(String filePath) async {
    final db = await openDatabase(File(filePath).absolute.path, readOnly: true);
    try {
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isEmpty || result.first.values.first != 'ok') {
        throw const ResourceDownloadException('Base SQLite corrompue');
      }
    } finally {
      await db.close();
    }
  }

  static String _categoryFolder(ResourceCategory category) =>
      switch (category) {
        ResourceCategory.bible => 'bibles',
        ResourceCategory.strong => 'strong',
        ResourceCategory.nave => 'nave',
        ResourceCategory.crossReferences => 'cross_references',
        ResourceCategory.dictionary => 'dictionaries',
        ResourceCategory.commentary => 'commentaries',
        ResourceCategory.timeline => 'timeline',
        ResourceCategory.audio => 'audio',
      };

  Future<ResourceDescriptor> _resolveDescriptor(
    ResourceDescriptor resource,
  ) async {
    if (resourceOverrides?.containsKey(resource.id) ?? false) return resource;
    final manifest =
        manifestOverrides ?? await (_manifestFuture ??= _loadManifest());
    final entry = manifest[_manifestId(resource.id)];
    if (entry == null || entry['status'] != 'available') return resource;
    final url = entry['downloadUrl'];
    final uri = url is String ? Uri.tryParse(url) : null;
    final metadataMatches = entry['version'] == resource.version &&
        entry['sizeBytes'] == resource.sizeBytes &&
        '${entry['sha256']}'.toLowerCase() == resource.sha256?.toLowerCase() &&
        entry['localFileName'] == resource.localFileName;
    if (uri?.scheme != 'https' || !metadataMatches) return resource;
    return resource.copyWith(downloadUrl: url as String);
  }

  static Future<Map<String, Map<String, Object?>>> _loadManifest() async {
    try {
      final decoded = jsonDecode(
        await rootBundle.loadString('resources_manifest.json'),
      ) as Map<String, Object?>;
      final entries = decoded['resources'] as List<Object?>? ?? const [];
      return {
        for (final value in entries)
          if (value is Map) '${value['id']}': Map<String, Object?>.from(value),
      };
    } catch (_) {
      return const {};
    }
  }

  static String _manifestId(OfflineResourceId id) => switch (id) {
        OfflineResourceId.neoCrampon => 'neo_crampon',
        _ => id.name,
      };
}

class ResourceUnavailableException implements Exception {
  const ResourceUnavailableException();
}

class ResourceBundledException implements Exception {
  const ResourceBundledException();
}

class ResourceDownloadException implements Exception {
  final String message;
  const ResourceDownloadException(this.message);
  @override
  String toString() => message;
}
