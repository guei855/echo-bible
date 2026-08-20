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
    int bookId,
    int chapter,
    int verse, {
    int versionId = 1,
  }) async {
    final db = await database;
    await saveReadingHistoryTo(
      db,
      bookId,
      chapter,
      verse,
      versionId: versionId,
    );
  }

  static Future<void> saveReadingHistoryTo(
    Database db,
    int bookId,
    int chapter,
    int verse, {
    int versionId = 1,
    DateTime? readAt,
  }) async {
    await db.transaction((transaction) async {
      // Une référence exacte déjà visitée remonte en tête au lieu de créer
      // une suite de doublons. Les autres passages restent intacts.
      await transaction.delete(
        'reading_history',
        where: 'book_id = ? AND chapter = ? AND verse = ? AND version_id = ?',
        whereArgs: [bookId, chapter, verse, versionId],
      );
      await transaction.insert('reading_history', {
        'book_id': bookId,
        'chapter': chapter,
        'verse': verse,
        'version_id': versionId,
        'read_at': (readAt ?? DateTime.now()).toIso8601String(),
      });
    });
  }

  // Récupérer la dernière position de lecture (pour le bouton "Reprendre la lecture")
  static Future<Map<String, dynamic>?> getLastReadingPosition() async {
    final db = await database;
    final result = await db.query(
      'reading_history',
      orderBy: 'read_at DESC, id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
