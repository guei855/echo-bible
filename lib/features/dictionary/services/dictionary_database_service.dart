import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:sqflite/sqflite.dart';

class DictionaryDatabaseService {
  final ResourceManager resourceManager;

  const DictionaryDatabaseService({
    this.resourceManager = const ResourceManager(),
  });

  Future<Database?> open() async {
    final descriptor = resourceManager.descriptor(OfflineResourceId.dictionary);
    final file = await resourceManager.installedFile(descriptor);
    if (!await file.exists()) return null;
    Database? database;
    try {
      database = await openDatabase(file.absolute.path, readOnly: true);
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        await database.close();
        return null;
      }
      await database.rawQuery('SELECT 1 FROM dictionary_entries LIMIT 1');
      return database;
    } catch (_) {
      await database?.close();
      return null;
    }
  }
}
