import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:sqflite/sqflite.dart';

class NaveDatabaseService {
  NaveDatabaseService._();

  /// Uses a short-lived read-only connection so deleting or reinstalling the
  /// optional Nave core never leaves a stale database handle behind.
  static Future<T> use<T>(Future<T> Function(Database database) action) async {
    final database = await BundledDatabase.open('nave_core.db');
    try {
      return await action(database);
    } finally {
      await database.close();
    }
  }
}
