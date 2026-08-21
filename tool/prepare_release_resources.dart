import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final release = Directory('release_resources');
  await release.create(recursive: true);
  final existing =
      jsonDecode(await File('resources_manifest.json').readAsString())
          as Map<String, Object?>;
  const regeneratedIds = {
    'strong',
    'crossReferences',
    'nave',
    'naveFrench',
  };
  final existingResources = (existing['resources'] as List)
      .map((resource) => Map<String, Object?>.from(resource as Map))
      .toList();
  final previousById = {
    for (final resource in existingResources) '${resource['id']}': resource,
  };
  final modules = existingResources
      .where((resource) => !regeneratedIds.contains(resource['id']))
      .toList();

  await _copyModule(
    File('assets/database/strong.db'),
    File('release_resources/common/strong/strong.db'),
    id: 'strong',
    language: 'common',
    category: 'strong',
    version: '2026-08-13-fr-strong-v1',
    sourceUrl: 'https://concordance.bible/Sg1910/download/',
    license: 'STEP Bible CC BY 4.0 ; Segond 1910 domaine public',
    modules: modules,
  );
  await _copyModule(
    File('assets/database/cross_references.db'),
    File('release_resources/common/cross_references/cross_references.db'),
    id: 'crossReferences',
    language: 'common',
    category: 'crossReferences',
    version: '2026-08-13',
    sourceUrl: 'https://www.openbible.info/labs/cross-references/',
    license: 'CC BY 4.0',
    modules: modules,
  );
  await _splitNaveModules(File('assets/database/nave.db'), modules);

  for (final module in modules) {
    final previous = previousById['${module['id']}'];
    final sameArtifact = previous != null &&
        previous['version'] == module['version'] &&
        previous['sizeBytes'] == module['sizeBytes'] &&
        previous['sha256'] == module['sha256'] &&
        previous['localFileName'] == module['localFileName'];
    if (sameArtifact && previous['status'] == 'available') {
      module['status'] = 'available';
      module['downloadUrl'] = previous['downloadUrl'];
    }
  }

  final manifest = const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'resources': modules,
  });
  await File('resources_manifest.json').writeAsString('$manifest\n');
  stdout.writeln(manifest);
}

Future<void> _splitNaveModules(
  File source,
  List<Map<String, Object?>> modules,
) async {
  final core = File('release_resources/en/nave/nave_core.db');
  await core.parent.create(recursive: true);
  await source.copy(core.path);
  final coreDb = await databaseFactory.openDatabase(core.absolute.path);
  try {
    await coreDb
        .execute('UPDATE nave_topics SET title_fr=NULL,normalized_fr=NULL');
    await coreDb.execute('UPDATE nave_sections SET title_fr=NULL');
    await coreDb.execute('DELETE FROM nave_translations');
    await coreDb.execute('''CREATE INDEX IF NOT EXISTS idx_nave_refs_verse
      ON nave_references(book_id,chapter,verse_start,verse_end,topic_id)''');
    await coreDb.execute('VACUUM');
  } finally {
    await coreDb.close();
  }
  modules.add(await _manifestEntry(
    core,
    id: 'nave',
    language: 'en',
    category: 'nave',
    version: '3.1',
    sourceUrl: 'https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave',
    license: 'Public Domain',
  ));

  final french = File('release_resources/fr/nave/nave_fr.db');
  await french.parent.create(recursive: true);
  if (await french.exists()) await french.delete();
  final sourceDb = await databaseFactory.openDatabase(source.absolute.path,
      options: OpenDatabaseOptions(readOnly: true));
  final frenchDb = await databaseFactory.openDatabase(french.absolute.path);
  try {
    await frenchDb.execute('''CREATE TABLE nave_translations(
      entity_type TEXT NOT NULL,entity_id INTEGER NOT NULL,
      language_code TEXT NOT NULL,translated_text TEXT NOT NULL,
      normalized_text TEXT NOT NULL,status TEXT NOT NULL
        CHECK(status IN ('verified','manual','machine','pending')),
      source TEXT NOT NULL,
      notes TEXT,
      PRIMARY KEY(entity_type,entity_id,language_code))''');
    await frenchDb.execute('''CREATE TABLE nave_aliases(
      id INTEGER PRIMARY KEY AUTOINCREMENT,topic_id INTEGER NOT NULL,
      language_code TEXT NOT NULL,alias_text TEXT NOT NULL,
      normalized_alias TEXT NOT NULL,source TEXT NOT NULL,status TEXT NOT NULL
        CHECK(status IN ('verified','manual','machine','pending')),
      UNIQUE(topic_id,language_code,normalized_alias))''');
    await frenchDb.execute(
        'CREATE INDEX idx_nave_translation_search ON nave_translations(language_code,entity_type,normalized_text)');
    await frenchDb.execute(
        'CREATE INDEX idx_nave_alias_search ON nave_aliases(language_code,normalized_alias)');
    await frenchDb.execute(
        'CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
    final editorial = jsonDecode(await File(
      'bible_builder/translations/nave_fr_editorial.json',
    ).readAsString()) as Map<String, Object?>;
    final language = editorial['languageCode']! as String;
    final source = editorial['source']! as String;
    final status = editorial['status']! as String;
    final notes = editorial['notes'] as String?;
    final translations = <Map<String, Object?>>[];
    final aliases = <Map<String, Object?>>[];
    final aliasKeys = <String>{};

    for (final value in editorial['topics']! as List<Object?>) {
      final topic = Map<String, Object?>.from(value! as Map);
      final titleEn = topic['titleEn']! as String;
      final occurrence = topic['occurrence'] as int? ?? 1;
      final matches = await sourceDb.query(
        'nave_topics',
        columns: ['id'],
        where: 'title_en=?',
        whereArgs: [titleEn],
        orderBy: 'id',
      );
      if (matches.length < occurrence) {
        throw StateError('Sujet Nave introuvable : $titleEn #$occurrence');
      }
      final topicId = matches[occurrence - 1]['id']! as int;
      final translatedText = topic['text']! as String;
      translations.add({
        'entity_type': 'topic',
        'entity_id': topicId,
        'language_code': language,
        'translated_text': translatedText,
        'normalized_text': _normalizeSearchText(translatedText),
        'status': status,
        'source': source,
        'notes': notes,
      });
      for (final alias in topic['aliases'] as List<Object?>? ?? const []) {
        final normalizedAlias = _normalizeSearchText(alias! as String);
        if (!aliasKeys.add('$topicId:$normalizedAlias')) continue;
        aliases.add({
          'topic_id': topicId,
          'language_code': language,
          'alias_text': alias,
          'normalized_alias': normalizedAlias,
          'source': source,
          'status': status,
        });
      }
    }

    for (final value in editorial['sections']! as List<Object?>) {
      final section = Map<String, Object?>.from(value! as Map);
      final sourceEn = section['sourceEn']! as String;
      final matches = await sourceDb.query(
        'nave_sections',
        columns: ['id'],
        where: 'title_en=?',
        whereArgs: [sourceEn],
      );
      if (matches.isEmpty) {
        throw StateError('Section Nave introuvable : $sourceEn');
      }
      final translatedText = section['text']! as String;
      for (final match in matches) {
        translations.add({
          'entity_type': 'section',
          'entity_id': match['id']! as int,
          'language_code': language,
          'translated_text': translatedText,
          'normalized_text': _normalizeSearchText(translatedText),
          'status': status,
          'source': source,
          'notes': notes,
        });
      }
    }
    await frenchDb.transaction((transaction) async {
      final batch = transaction.batch();
      for (final row in translations) {
        batch.insert('nave_translations', row);
      }
      for (final row in aliases) {
        batch.insert('nave_aliases', row);
      }
      batch.insert('metadata', {'key': 'language', 'value': language});
      batch.insert('metadata', {'key': 'version', 'value': '4'});
      batch.insert('metadata', {'key': 'license', 'value': 'CC BY-SA 4.0'});
      batch.insert('metadata', {'key': 'source', 'value': source});
      batch.insert('metadata', {
        'key': 'topic_translations',
        'value':
            '${translations.where((row) => row['entity_type'] == 'topic').length}',
      });
      batch.insert('metadata', {
        'key': 'section_translations',
        'value':
            '${translations.where((row) => row['entity_type'] == 'section').length}',
      });
      batch
          .insert('metadata', {'key': 'aliases', 'value': '${aliases.length}'});
      await batch.commit(noResult: true);
    });
  } finally {
    await sourceDb.close();
    await frenchDb.close();
  }
  modules.add(await _manifestEntry(
    french,
    id: 'naveFrench',
    language: 'fr',
    category: 'nave',
    version: '4',
    sourceUrl: 'https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave',
    license: 'CC BY-SA 4.0 (French translation layer)',
  ));
}

String _normalizeSearchText(String value) {
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'œ': 'oe',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ÿ': 'y',
  };
  var normalized = value.toLowerCase();
  replacements.forEach(
    (character, replacement) =>
        normalized = normalized.replaceAll(character, replacement),
  );
  return normalized.replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();
}

Future<void> _copyModule(
  File source,
  File destination, {
  required String id,
  required String language,
  required String category,
  required String version,
  required String sourceUrl,
  required String license,
  required List<Map<String, Object?>> modules,
}) async {
  await destination.parent.create(recursive: true);
  await source.copy(destination.path);
  modules.add(await _manifestEntry(
    destination,
    id: id,
    language: language,
    category: category,
    version: version,
    sourceUrl: sourceUrl,
    license: license,
  ));
}

Future<Map<String, Object?>> _manifestEntry(
  File file, {
  required String id,
  required String language,
  required String category,
  required String version,
  required String sourceUrl,
  required String license,
}) async =>
    {
      'id': id,
      'language': language,
      'category': category,
      'version': version,
      'sizeBytes': await file.length(),
      'sha256': (await sha256.bind(file.openRead()).first).toString(),
      'localFileName': path.basename(file.path),
      'releasePath': path
          .relative(file.path, from: 'release_resources')
          .replaceAll('\\', '/'),
      'sourceUrl': sourceUrl,
      'license': license,
    };
