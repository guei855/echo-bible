import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class NaveTranslationService {
  const NaveTranslationService._();
  static Database? _database;

  static Future<String?> translation(String entityType, int entityId) async {
    final db = await _openIfInstalled();
    if (db == null) return null;
    final rows = await db.query(
      'nave_translations',
      columns: ['translated_text'],
      where: 'entity_type=? AND entity_id=?',
      whereArgs: [entityType, entityId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['translated_text'] as String;
  }

  static Future<Database?> _openIfInstalled() async {
    if (_database != null) return _database;
    const manager = ResourceManager();
    final descriptor = manager.descriptor(OfflineResourceId.naveFrench);
    final file = await manager.installedFile(descriptor);
    if (await file.exists()) {
      return _database = await openDatabase(file.path, readOnly: true);
    }
    const compileTimeFlutterTest = bool.fromEnvironment('FLUTTER_TEST');
    final isFlutterTest = compileTimeFlutterTest ||
        Platform.environment['FLUTTER_TEST']?.toLowerCase() == 'true';
    if (!isFlutterTest) return null;
    final development = File(path.join(
      Directory.current.path,
      'release_resources',
      'fr',
      'nave',
      descriptor.localFileName,
    ));
    if (!await development.exists()) return null;
    return _database = await openDatabase(development.path, readOnly: true);
  }
}
