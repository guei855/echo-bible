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
  final modules = (existing['resources'] as List)
      .map((resource) => Map<String, Object?>.from(resource as Map))
      .where((resource) => resource['category'] == 'bible')
      .toList();

  await _copyModule(
    File('assets/database/strong.db'),
    File('release_resources/common/strong/strong.db'),
    id: 'strong',
    language: 'common',
    category: 'strong',
    version: '2026-08-13',
    sourceUrl: 'https://stepbible.org/',
    license: 'CC BY 4.0',
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
    await coreDb.execute('VACUUM');
  } finally {
    await coreDb.close();
  }
  modules.add(await _manifestEntry(
    core,
    id: 'nave',
    language: 'en',
    category: 'nave',
    version: '3.0',
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
      translated_text TEXT NOT NULL,translation_status TEXT NOT NULL,
      translation_source TEXT NOT NULL,
      PRIMARY KEY(entity_type,entity_id))''');
    await frenchDb.execute(
        'CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
    final translations = await sourceDb.query(
      'nave_translations',
      where: "language='fr' AND translation_status<>'pending'",
    );
    final reviewed = <String, Map<String, Object?>>{
      for (final row in translations)
        '${row['entity_type']}:${row['entity_id']}': row,
    };
    final reviewFile = File('bible_builder/translations/nave_fr_review.csv');
    if (await reviewFile.exists()) {
      final lines = await reviewFile.readAsLines();
      for (final line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        final fields = _parseCsvLine(line);
        if (fields.length < 5 ||
            fields[3].trim().isEmpty ||
            fields[4].trim() == 'pending') {
          continue;
        }
        reviewed['${fields[0]}:${fields[1]}'] = {
          'entity_type': fields[0],
          'entity_id': int.parse(fields[1]),
          'translated_text': fields[3],
          'translation_status': fields[4],
          'translation_source': 'ECHO BIBLE reviewed translation layer',
        };
      }
    }
    await frenchDb.transaction((transaction) async {
      final batch = transaction.batch();
      for (final row in reviewed.values) {
        batch.insert('nave_translations', {
          'entity_type': row['entity_type'],
          'entity_id': row['entity_id'],
          'translated_text': row['translated_text'],
          'translation_status': row['translation_status'],
          'translation_source': row['translation_source'],
        });
      }
      batch.insert('metadata', {'key': 'language', 'value': 'fr'});
      batch.insert('metadata', {'key': 'version', 'value': '1'});
      batch.insert('metadata', {'key': 'license', 'value': 'CC BY-SA 4.0'});
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
    version: '1',
    sourceUrl: 'https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave',
    license: 'CC BY-SA 4.0 (French translation layer)',
  ));
}

List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        buffer.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(character);
    }
  }
  fields.add(buffer.toString());
  return fields;
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
