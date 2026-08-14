import 'package:sqflite/sqflite.dart';

/// Schéma autonome des documents Echo Étude.
///
/// Cette base ne contient aucun texte biblique et n'a aucune clé étrangère
/// vers les modules Bible, Strong, Vigouroux ou références croisées.
class StudyDocumentSchema {
  const StudyDocumentSchema._();

  static Future<void> ensure(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        document_type TEXT NOT NULL DEFAULT 'free',
        primary_reference TEXT,
        tags_json TEXT NOT NULL DEFAULT '[]',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        status TEXT NOT NULL DEFAULT 'draft',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_blocks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        study_id INTEGER NOT NULL,
        block_id TEXT NOT NULL UNIQUE,
        position INTEGER NOT NULL,
        block_type TEXT NOT NULL DEFAULT 'text',
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(study_id) REFERENCES study_documents(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_metadata(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_documents_sort '
      'ON study_documents(is_pinned DESC, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_blocks_order '
      'ON study_blocks(study_id, position)',
    );
  }
}
