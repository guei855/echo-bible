import 'package:sqflite/sqflite.dart';

/// Tables locales de l'espace de travail. Le texte biblique reste dans
/// `verses` et n'est jamais dupliqué.
class StudySchema {
  const StudySchema._();

  static Future<void> ensure(Database db) async {
    await db.transaction((transaction) async {
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS bible_versions(
          id INTEGER PRIMARY KEY,
          code TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          abbreviation TEXT NOT NULL,
          language TEXT NOT NULL,
          copyright TEXT,
          is_default INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS verse_translations(
          version_id INTEGER NOT NULL,
          verse_id INTEGER NOT NULL,
          text TEXT NOT NULL,
          PRIMARY KEY(version_id, verse_id),
          FOREIGN KEY(version_id) REFERENCES bible_versions(id) ON DELETE CASCADE,
          FOREIGN KEY(verse_id) REFERENCES verses(id) ON DELETE CASCADE
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS study_tabs(
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          state_json TEXT NOT NULL DEFAULT '{}',
          scroll_position REAL NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS personal_studies(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS study_sections(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          study_id INTEGER NOT NULL,
          position INTEGER NOT NULL,
          kind TEXT NOT NULL DEFAULT 'text',
          content TEXT NOT NULL DEFAULT '',
          reference TEXT,
          style_json TEXT NOT NULL DEFAULT '{}',
          FOREIGN KEY(study_id) REFERENCES personal_studies(id) ON DELETE CASCADE
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS tags(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          color TEXT NOT NULL DEFAULT '#2563EB',
          created_at TEXT NOT NULL
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS verse_tags(
          verse_id INTEGER NOT NULL,
          tag_id INTEGER NOT NULL,
          PRIMARY KEY(verse_id, tag_id),
          FOREIGN KEY(verse_id) REFERENCES verses(id) ON DELETE CASCADE,
          FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS verse_links(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_verse_id INTEGER NOT NULL,
          target_verse_id INTEGER NOT NULL,
          label TEXT,
          created_at TEXT NOT NULL,
          UNIQUE(source_verse_id, target_verse_id),
          FOREIGN KEY(source_verse_id) REFERENCES verses(id) ON DELETE CASCADE,
          FOREIGN KEY(target_verse_id) REFERENCES verses(id) ON DELETE CASCADE
        )
      ''');
      await transaction.execute('''
        CREATE TABLE IF NOT EXISTS text_markings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse_number INTEGER NOT NULL,
          version_id INTEGER NOT NULL DEFAULT 1,
          start_offset INTEGER,
          end_offset INTEGER,
          selected_text TEXT,
          marking_type TEXT NOT NULL CHECK(marking_type IN ('highlight', 'underline')),
          color TEXT NOT NULL,
          created_at TEXT NOT NULL,
          CHECK(
            (start_offset IS NULL AND end_offset IS NULL) OR
            (start_offset IS NOT NULL AND end_offset IS NOT NULL AND start_offset >= 0 AND end_offset > start_offset)
          )
        )
      ''');
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_verse_translations_verse '
        'ON verse_translations(verse_id, version_id)',
      );
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_sections_study_position '
        'ON study_sections(study_id, position)',
      );
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_verse_tags_tag '
        'ON verse_tags(tag_id, verse_id)',
      );
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_verse_links_source '
        'ON verse_links(source_verse_id)',
      );
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_verse_links_target '
        'ON verse_links(target_verse_id)',
      );
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_text_markings_passage '
        'ON text_markings(book_id, chapter, verse_number, version_id)',
      );
      await transaction.execute(
        'CREATE INDEX IF NOT EXISTS idx_cross_references_verse '
        'ON cross_references(verse_id)',
      );
      // Strong is an optional downloadable resource. These two legacy tables
      // only duplicated derived data inside bible.db and are never user data.
      await transaction.execute('DROP TABLE IF EXISTS strong_words');
      await transaction.execute('DROP TABLE IF EXISTS strong_dictionary');
    });

    final noteColumns = await db.rawQuery('PRAGMA table_info(notes)');
    if (noteColumns.isNotEmpty) {
      final names = noteColumns.map((column) => column['name']).toSet();
      if (!names.contains('title')) {
        await db.execute('ALTER TABLE notes ADD COLUMN title TEXT');
      }
      if (!names.contains('updated_at')) {
        await db.execute('ALTER TABLE notes ADD COLUMN updated_at TEXT');
      }
      for (final column in const {
        'version_id': 'INTEGER NOT NULL DEFAULT 1',
        'start_offset': 'INTEGER',
        'end_offset': 'INTEGER',
        'selected_text': 'TEXT',
      }.entries) {
        if (!names.contains(column.key)) {
          await db.execute(
            'ALTER TABLE notes ADD COLUMN ${column.key} ${column.value}',
          );
        }
      }
    }

    final historyColumns = await db.rawQuery(
      'PRAGMA table_info(reading_history)',
    );
    if (historyColumns.isNotEmpty) {
      final names = historyColumns.map((column) => column['name']).toSet();
      if (!names.contains('version_id')) {
        await db.execute(
          'ALTER TABLE reading_history '
          'ADD COLUMN version_id INTEGER NOT NULL DEFAULT 1',
        );
      }
      // Conserve uniquement la visite la plus récente pour chaque référence
      // exacte. Cette migration est volontairement limitée aux vrais doublons.
      await db.execute('''
        DELETE FROM reading_history
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM reading_history
          GROUP BY version_id, book_id, chapter, verse
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reading_history_recent '
        'ON reading_history(read_at DESC, id DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reading_history_reference '
        'ON reading_history(version_id, book_id, chapter, verse)',
      );
    }

    final planColumns = await db.rawQuery('PRAGMA table_info(reading_plans)');
    if (planColumns.isNotEmpty) {
      final names = planColumns.map((column) => column['name']).toSet();
      for (final column in const {
        'description': 'TEXT',
        'start_date': 'TEXT',
        'is_personal': 'INTEGER NOT NULL DEFAULT 1',
        'is_active': 'INTEGER NOT NULL DEFAULT 0',
        'created_at': 'TEXT',
      }.entries) {
        if (!names.contains(column.key)) {
          await db.execute(
            'ALTER TABLE reading_plans ADD COLUMN '
            '${column.key} ${column.value}',
          );
        }
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reading_plan_items_plan_day '
        'ON reading_plan_items(plan_id, day)',
      );
    }
  }
}
