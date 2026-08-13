import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:sqflite/sqflite.dart';

class NaveDatabaseService {
  NaveDatabaseService._();
  static Database? _database;
  static Future<Database> get database async =>
      _database ??= await BundledDatabase.open('nave_core.db');
}
