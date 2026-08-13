import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:sqflite/sqflite.dart';

class CrossReferenceDatabaseService {
  CrossReferenceDatabaseService._();

  /// Short-lived connections allow the optional resource to be removed and
  /// reinstalled without retaining a stale SQLite handle.
  static Future<T> use<T>(Future<T> Function(Database database) action) async {
    final database = await BundledDatabase.open('cross_references.db');
    try {
      return await action(database);
    } finally {
      await database.close();
    }
  }
}
