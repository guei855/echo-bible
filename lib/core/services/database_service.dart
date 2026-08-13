import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:echo_bible/core/database/database_initializer.dart';
import 'package:echo_bible/core/database/study_schema.dart';

class DatabaseService {
  static Database? _database;

  // Obtenir l'instance unique de la base de données locale
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    await DatabaseInitializer.initialize();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bible.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onOpen: StudySchema.ensure,
    );
  }

  // Enregistrer ou mettre à jour la position de lecture actuelle
  static Future<void> saveReadingHistory(
      int bookId, int chapter, int verse) async {
    final db = await database;
    await db.insert(
      'reading_history',
      {
        'book_id': bookId,
        'chapter': chapter,
        'verse': verse,
        'read_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Récupérer la dernière position de lecture (pour le bouton "Reprendre la lecture")
  static Future<Map<String, dynamic>?> getLastReadingPosition() async {
    final db = await database;
    final result = await db.query(
      'reading_history',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
