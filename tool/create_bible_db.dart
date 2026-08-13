import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

void main() async {
  stdout.writeln('========================================');
  stdout.writeln('Génération de la base de données bible.db');
  stdout.writeln('========================================\r\n');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Chemin absolu direct vers assets/database/bible.db
  final directory = Directory('assets/database');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final dbPath = '${directory.absolute.path}/bible.db';
  final dbFile = File(dbPath);

  if (await dbFile.exists()) {
    await dbFile.delete();
    stdout.writeln('Ancienne base de données supprimée.');
  }

  // Nettoyer aussi le cache de sqflite_common_ffi s'il existe
  final cacheDir =
      Directory('.dart_tool/sqflite_common_ffi/databases/assets/database');
  if (await cacheDir.exists()) {
    await cacheDir.delete(recursive: true);
  }

  stdout.writeln('Création de la structure des tables...');
  final db = await databaseFactory.openDatabase(dbPath,
      options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute(
                'CREATE TABLE books(id INTEGER PRIMARY KEY, name TEXT, abbreviation TEXT, testament TEXT, position INTEGER, chapters_count INTEGER)');
            await db.execute(
                'CREATE TABLE chapters(id INTEGER PRIMARY KEY, book_id INTEGER, chapter_number INTEGER, verses_count INTEGER)');
            await db.execute(
                'CREATE TABLE verses(id INTEGER PRIMARY KEY, book_id INTEGER, chapter_number INTEGER, verse_number INTEGER, text TEXT)');
            await db.execute(
                'CREATE TABLE verse_raw(verse_id INTEGER PRIMARY KEY, usfx TEXT)');
            await db.execute(
                'CREATE TABLE cross_references(id INTEGER PRIMARY KEY, verse_id INTEGER, reference TEXT)');
            await db.execute(
                'CREATE TABLE favorites(id INTEGER PRIMARY KEY, verse_id INTEGER, created_at TEXT)');
            await db.execute(
                'CREATE TABLE highlights(id INTEGER PRIMARY KEY, verse_id INTEGER, color TEXT)');
            await db.execute(
                'CREATE TABLE notes(id INTEGER PRIMARY KEY, verse_id INTEGER, title TEXT, note TEXT, created_at TEXT, updated_at TEXT)');
            await db.execute(
                'CREATE TABLE reading_history(id INTEGER PRIMARY KEY, book_id INTEGER, chapter INTEGER, verse INTEGER, read_at TEXT)');
            await db.execute(
                'CREATE TABLE reading_plans(id INTEGER PRIMARY KEY, title TEXT, duration INTEGER, description TEXT, start_date TEXT, is_personal INTEGER NOT NULL DEFAULT 1, is_active INTEGER NOT NULL DEFAULT 0, created_at TEXT)');
            await db.execute(
                'CREATE TABLE reading_plan_items(id INTEGER PRIMARY KEY, plan_id INTEGER, day INTEGER, book_id INTEGER, chapter INTEGER, start_verse INTEGER, end_verse INTEGER)');
            await db.execute(
                'CREATE TABLE bookmarks(id INTEGER PRIMARY KEY, book_id INTEGER, chapter INTEGER, verse INTEGER)');
            await db.execute(
                'CREATE TABLE search_index(verse_id INTEGER, text TEXT)');
            await db.execute(
                "CREATE TABLE tags(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, color TEXT NOT NULL DEFAULT '#2563EB', created_at TEXT NOT NULL)");
            await db.execute(
                'CREATE TABLE verse_tags(verse_id INTEGER NOT NULL, tag_id INTEGER NOT NULL, PRIMARY KEY(verse_id, tag_id))');
            await db.execute(
                'CREATE TABLE verse_links(id INTEGER PRIMARY KEY AUTOINCREMENT, source_verse_id INTEGER NOT NULL, target_verse_id INTEGER NOT NULL, label TEXT, created_at TEXT NOT NULL, UNIQUE(source_verse_id, target_verse_id))');
          }));

  final xmlFile = File('assets/database/fraLSG_usfx.xml');
  if (!await xmlFile.exists()) {
    stdout.writeln(
        'ERREUR : Le fichier fraLSG_usfx.xml est introuvable dans assets/database/ !');
    return;
  }

  stdout.writeln(
      'Lecture et analyse du fichier XML (cela peut prendre quelques secondes)...');
  final xmlString = await xmlFile.readAsString();
  final document = XmlDocument.parse(xmlString);
  final bookElements = document.findAllElements("book");

  int bookIdCounter = 1;
  int globalVerseIdCounter = 1;
  int totalChapters = 0;
  int totalVerses = 0;

  await db.transaction((txn) async {
    for (var bookEl in bookElements) {
      final bookIdAttr = bookEl.getAttribute("id") ?? "";
      final nameEl = bookEl.findElements("toc").firstOrNull ??
          bookEl.findElements("name").firstOrNull;
      String bookName = nameEl?.innerText.trim() ?? "";
      if (bookName.isEmpty) {
        bookName = bookIdAttr;
      }

      String testament = bookIdCounter <= 39 ? 'Ancien' : 'Nouveau';

      int currentChapter = 1;
      Map<int, List<Map<String, dynamic>>> versesByChapter = {};

      for (var node in bookEl.children) {
        if (node is XmlElement) {
          if (node.name.local == 'c') {
            final cId = node.getAttribute("id") ?? node.getAttribute("n") ?? "";
            final parts = cId.split('.');
            final parsedNum = int.tryParse(parts.isNotEmpty ? parts.last : cId);
            if (parsedNum != null) {
              currentChapter = parsedNum;
            }
          } else {
            final fetchedVerses =
                node.name.local == 'v' ? [node] : node.findAllElements('v');

            for (var verseEl in fetchedVerses) {
              final vId =
                  verseEl.getAttribute("id") ?? verseEl.getAttribute("n") ?? "";

              int verseNum = 1;
              if (vId.contains('-')) {
                verseNum =
                    int.tryParse(vId.split('.').last.split('-').first) ?? 1;
              } else if (vId.contains('.')) {
                verseNum = int.tryParse(vId.split('.').last) ?? 1;
              } else {
                verseNum = int.tryParse(vId) ?? 1;
              }

              String textClean = _cleanVerseTextStatic(verseEl);
              if (textClean.isEmpty) {
                textClean = verseEl.innerText.trim();
              }

              String textUsfx = verseEl.toString();

              List<String> crossRefs = [];
              for (var xEl in verseEl.findAllElements('x')) {
                crossRefs.add(xEl.innerText.trim());
              }

              versesByChapter.putIfAbsent(currentChapter, () => []);
              versesByChapter[currentChapter]!.add({
                'verse_number': verseNum,
                'text_clean': textClean,
                'text_usfx': textUsfx,
                'cross_references': crossRefs,
              });
            }
          }
        }
      }

      int chaptersCount = versesByChapter.keys.isNotEmpty
          ? versesByChapter.keys.reduce((a, b) => a > b ? a : b)
          : 1;
      totalChapters += chaptersCount;

      await txn.insert('books', {
        'id': bookIdCounter,
        'name': bookName,
        'abbreviation': bookIdAttr,
        'testament': testament,
        'position': bookIdCounter,
        'chapters_count': chaptersCount,
      });

      for (var entry in versesByChapter.entries) {
        int chapNum = entry.key;
        List<Map<String, dynamic>> versesList = entry.value;

        await txn.insert('chapters', {
          'book_id': bookIdCounter,
          'chapter_number': chapNum,
          'verses_count': versesList.length,
        });

        for (var vData in versesList) {
          final currentVerseId = globalVerseIdCounter;
          totalVerses++;

          await txn.insert('verses', {
            'id': currentVerseId,
            'book_id': bookIdCounter,
            'chapter_number': chapNum,
            'verse_number': vData['verse_number'],
            'text': vData['text_clean'],
          });

          await txn.insert('verse_raw', {
            'verse_id': currentVerseId,
            'usfx': vData['text_usfx'],
          });

          for (String ref in vData['cross_references']) {
            await txn.insert('cross_references', {
              'verse_id': currentVerseId,
              'reference': ref,
            });
          }

          await txn.insert('search_index', {
            'verse_id': currentVerseId,
            'text': vData['text_clean'],
          });

          globalVerseIdCounter++;
        }
      }

      stdout.writeln('-> Livre traité : $bookName ($chaptersCount chapitres)');
      bookIdCounter++;
    }
  });

  await db.close();

  stdout.writeln('\r\n========================================');
  stdout.writeln('RÉSULTAT DE LA GÉNÉRATION :');
  stdout.writeln('${bookIdCounter - 1} livres');
  stdout.writeln('$totalChapters chapitres');
  stdout.writeln('$totalVerses versets');
  stdout.writeln('Base créée avec succès dans : $dbPath');
  stdout.writeln('========================================');
}

String _cleanVerseTextStatic(XmlElement verseEl) {
  StringBuffer sb = StringBuffer();
  var nextSibling = verseEl.nextSibling;
  while (nextSibling != null) {
    if (nextSibling is XmlElement) {
      if (nextSibling.name.local == 'v' || nextSibling.name.local == 'c') {
        break;
      }
      if (['x', 'f', 'ref', 'note', 'milestone']
          .contains(nextSibling.name.local)) {
        nextSibling = nextSibling.nextSibling;
        continue;
      }
      sb.write(_extractTextRecursiveStatic(nextSibling));
    } else if (nextSibling is XmlText) {
      sb.write(nextSibling.value);
    }
    nextSibling = nextSibling.nextSibling;
  }

  return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _extractTextRecursiveStatic(XmlNode node) {
  if (node is XmlText) {
    return node.value;
  }
  if (node is XmlElement) {
    if (['x', 'f', 'ref', 'note', 'milestone'].contains(node.name.local)) {
      return '';
    }
    StringBuffer buffer = StringBuffer();
    for (var child in node.children) {
      buffer.write(_extractTextRecursiveStatic(child));
    }
    return buffer.toString();
  }
  return '';
}
