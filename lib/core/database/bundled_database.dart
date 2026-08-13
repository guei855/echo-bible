import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Opens an optional study module from application storage.
///
/// During Flutter tests only, generated release modules are read directly from
/// the workspace. Production never falls back to bundled heavyweight assets.
class BundledDatabase {
  const BundledDatabase._();

  static Future<Database> open(String fileName) async {
    final id = switch (fileName) {
      'strong.db' => OfflineResourceId.strong,
      'cross_references.db' => OfflineResourceId.crossReferences,
      'nave_core.db' || 'nave.db' => OfflineResourceId.nave,
      _ => throw ResourceNotInstalledException(fileName),
    };
    const manager = ResourceManager();
    final descriptor = manager.descriptor(id);
    final installed = await manager.installedFile(descriptor);
    if (await installed.exists()) {
      return openDatabase(installed.path, readOnly: true);
    }

    const compileTimeFlutterTest = bool.fromEnvironment('FLUTTER_TEST');
    final isFlutterTest = compileTimeFlutterTest ||
        Platform.environment['FLUTTER_TEST']?.toLowerCase() == 'true';
    if (isFlutterTest) {
      final development = File(path.join(
        Directory.current.path,
        'release_resources',
        descriptor.language.name,
        _folder(descriptor.category),
        descriptor.localFileName,
      ));
      if (await development.exists()) {
        return openDatabase(development.path, readOnly: true);
      }
    }
    throw ResourceNotInstalledException(descriptor.name);
  }

  static String _folder(ResourceCategory category) => switch (category) {
        ResourceCategory.strong => 'strong',
        ResourceCategory.crossReferences => 'cross_references',
        ResourceCategory.nave => 'nave',
        _ => category.name,
      };
}

class ResourceNotInstalledException implements Exception {
  final String resource;
  const ResourceNotInstalledException(this.resource);
  @override
  String toString() => 'Ressource non installée : $resource';
}
