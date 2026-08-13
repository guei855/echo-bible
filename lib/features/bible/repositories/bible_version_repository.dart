import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/models/bible_version.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Unique access layer for the bundled LSG and installed Bible modules.
class BibleVersionRepository {
  const BibleVersionRepository._();

  static const _activeVersionKey = 'selected_bible_version_id';
  static const _moduleIdBase = 100;

  static Future<List<BibleVersion>> getInstalledVersions() async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'bible_versions',
      where: 'is_default = 1',
      orderBy: 'id ASC',
    );
    final versions = rows.map(BibleVersion.fromMap).toList();
    const manager = ResourceManager();
    for (final descriptor in manager.catalog().where(
          (resource) =>
              resource.category == ResourceCategory.bible &&
              resource.id != OfflineResourceId.lsg,
        )) {
      final file = await _moduleFile(manager, descriptor);
      if (file == null) continue;
      Database? module;
      try {
        module = await openDatabase(file.path, readOnly: true);
        final metadataRows = await module.query('metadata');
        final metadata = {
          for (final row in metadataRows)
            row['key'] as String: row['value'] as String,
        };
        versions.add(BibleVersion(
          id: _moduleIdBase + descriptor.id.index,
          code: metadata['code'] ?? descriptor.id.name,
          name: metadata['name'] ?? descriptor.name,
          abbreviation: metadata['shortName'] ?? descriptor.shortName,
          language: metadata['language'] ?? descriptor.language.name,
          copyright: descriptor.license,
          isDefault: false,
        ));
      } on DatabaseException {
        // A manually removed or corrupt module must not break the LSG reader.
      } finally {
        await module?.close();
      }
    }
    return versions;
  }

  static Future<BibleVersion> getActiveVersion() async {
    final versions = await getInstalledVersions();
    final id = await getSelectedVersionId(versions);
    return versions.firstWhere((version) => version.id == id);
  }

  static Future<int> getSelectedVersionId(List<BibleVersion> versions) async {
    final preferences = await SharedPreferences.getInstance();
    final selected = preferences.getInt(_activeVersionKey);
    if (selected != null && versions.any((version) => version.id == selected)) {
      return selected;
    }
    final fallback = versions.firstWhere(
      (version) => version.isDefault,
      orElse: () => versions.first,
    );
    if (selected != fallback.id) {
      await preferences.setInt(_activeVersionKey, fallback.id);
    }
    return fallback.id;
  }

  static Future<void> setActiveVersion(int versionId) async {
    final versions = await getInstalledVersions();
    if (!versions.any((version) => version.id == versionId)) {
      throw ArgumentError.value(
          versionId, 'versionId', 'Version non installée');
    }
    await setSelectedVersionId(versionId);
  }

  static Future<void> setSelectedVersionId(int versionId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_activeVersionKey, versionId);
  }

  static Future<List<Map<String, Object?>>> getChapter({
    required int bookId,
    required int chapterNumber,
    required int versionId,
  }) async {
    final module = await _databaseForVersion(versionId);
    if (module == null) return const [];
    try {
      return module.rawQuery('''
        SELECT id,book_id,chapter_number,verse_number,text,
          0 AS uses_default_text
        FROM verses
        WHERE book_id=? AND chapter_number=?
        ORDER BY verse_number
      ''', [bookId, chapterNumber]);
    } finally {
      if (versionId >= _moduleIdBase) await module.close();
    }
  }

  static Future<Map<String, Object?>?> getVerse({
    required int bookId,
    required int chapterNumber,
    required int verseNumber,
    required int versionId,
  }) async {
    final rows = await getChapter(
      bookId: bookId,
      chapterNumber: chapterNumber,
      versionId: versionId,
    );
    return rows.cast<Map<String, Object?>?>().firstWhere(
          (row) => row?['verse_number'] == verseNumber,
          orElse: () => null,
        );
  }

  static Future<List<BibleBook>> getBooks({int? versionId}) async {
    final selected = versionId ?? (await getActiveVersion()).id;
    final module = await _databaseForVersion(selected);
    if (module == null) return const [];
    try {
      final rows = await module.query('books', orderBy: 'id ASC');
      return rows.map((row) => BibleBook.fromMap(row)).toList();
    } finally {
      if (selected >= _moduleIdBase) await module.close();
    }
  }

  // Compatibility aliases kept at call sites while all access remains here.
  static Future<List<BibleVersion>> getVersions() => getInstalledVersions();
  static Future<List<Map<String, Object?>>> loadChapter({
    required int bookId,
    required int chapterNumber,
    required int versionId,
  }) =>
      getChapter(
        bookId: bookId,
        chapterNumber: chapterNumber,
        versionId: versionId,
      );

  static Future<Database?> _databaseForVersion(int versionId) async {
    if (versionId < _moduleIdBase) return DatabaseService.database;
    final index = versionId - _moduleIdBase;
    if (index < 0 || index >= OfflineResourceId.values.length) return null;
    const manager = ResourceManager();
    final descriptor = manager.descriptor(OfflineResourceId.values[index]);
    final file = await _moduleFile(manager, descriptor);
    if (file == null) return null;
    try {
      return await openDatabase(file.path, readOnly: true);
    } on DatabaseException {
      return null;
    }
  }

  static Future<File?> _moduleFile(
    ResourceManager manager,
    ResourceDescriptor descriptor,
  ) async {
    final installed = await manager.installedFile(descriptor);
    if (await installed.exists()) return installed;
    const isCompileTimeTest = bool.fromEnvironment('FLUTTER_TEST');
    const disableDevelopmentFallback = bool.fromEnvironment(
      'ECHO_BIBLE_DISABLE_DEV_RESOURCE_FALLBACK',
    );
    final isTest = isCompileTimeTest ||
        Platform.environment['FLUTTER_TEST']?.toLowerCase() == 'true';
    if (!isTest || disableDevelopmentFallback) return null;
    final development = File(path.join(
      Directory.current.path,
      'release_resources',
      descriptor.language.name,
      'bibles',
      descriptor.localFileName,
    ));
    return await development.exists() ? development : null;
  }
}
