import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class CommentaryDatabaseService {
  CommentaryDatabaseService._();

  static Database? _database;

  static Future<Database?> get database async {
    if (_database != null) return _database;
    final path = join(await getDatabasesPath(), 'commentaries.db');
    if (!await databaseExists(path)) return null;
    _database = await openDatabase(path, readOnly: true);
    return _database;
  }
}
