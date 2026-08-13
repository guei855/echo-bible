import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:sqflite/sqflite.dart';

class StrongDatabaseService {
  StrongDatabaseService._();
  static Database? _database;
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await BundledDatabase.open('strong.db');
    ResourceManager.registerReleaseHandler(OfflineResourceId.strong, close);
    return _database!;
  }

  static Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await database.close();
  }
}
