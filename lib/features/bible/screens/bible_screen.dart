import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/bible/widgets/reader_host_bindings.dart';
import 'package:flutter/material.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  BibleBook? _book;
  int _chapter = 1;
  int _readerRevision = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _openLastPassage();
  }

  Future<void> _openLastPassage() async {
    final database = await DatabaseService.database;
    final position = await DatabaseService.getLastReadingPosition();
    final requestedBookId = position?['book_id'] as int?;
    var rows = requestedBookId == null
        ? <Map<String, Object?>>[]
        : await database.query(
            'books',
            where: 'id = ?',
            whereArgs: [requestedBookId],
            limit: 1,
          );
    if (rows.isEmpty) {
      rows = await database.query(
        'books',
        orderBy: 'position ASC, id ASC',
        limit: 1,
      );
    }
    if (!mounted) return;
    setState(() {
      _book = rows.isEmpty ? null : BibleBook.fromMap(rows.first);
      _chapter = position?['chapter'] as int? ?? 1;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final book = _book;
    if (book == null) {
      return const Scaffold(
        body: Center(child: Text('Aucun livre biblique disponible.')),
      );
    }
    return ReaderHostBindings(
      initialVersionId: null,
      onChapterChanged: (chapter) => _chapter = chapter,
      onVersionChanged: (_) {},
      onPassageChanged: (selection) {
        setState(() {
          _book = selection.book;
          _chapter = selection.chapter;
          _readerRevision++;
        });
      },
      child: ChapterReaderScreen(
        key: ValueKey('${book.id}_$_readerRevision'),
        book: book,
        initialChapter: _chapter,
      ),
    );
  }
}
