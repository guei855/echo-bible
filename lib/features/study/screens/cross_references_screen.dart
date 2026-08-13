import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:flutter/material.dart';

class CrossReferencesScreen extends StatefulWidget {
  final int? sourceBook;
  final String? sourceBookName;
  final int? sourceChapter;
  final int? sourceVerse;
  final int? sourceVersionId;

  const CrossReferencesScreen({
    super.key,
    this.sourceBook,
    this.sourceBookName,
    this.sourceChapter,
    this.sourceVerse,
    this.sourceVersionId,
  });

  @override
  State<CrossReferencesScreen> createState() => _CrossReferencesScreenState();
}

class _CrossReferencesScreenState extends State<CrossReferencesScreen> {
  final _book = TextEditingController();
  final _chapter = TextEditingController();
  final _verse = TextEditingController();
  List<CrossReference>? _references;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.sourceBook != null &&
        widget.sourceChapter != null &&
        widget.sourceVerse != null) {
      _book.text = '${widget.sourceBook}';
      _chapter.text = '${widget.sourceChapter}';
      _verse.text = '${widget.sourceVerse}';
      _search();
    }
  }

  @override
  void dispose() {
    _book.dispose();
    _chapter.dispose();
    _verse.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final book = int.tryParse(_book.text);
    final chapter = int.tryParse(_chapter.text);
    final verse = int.tryParse(_verse.text);
    if (book == null || chapter == null || verse == null) return;

    setState(() {
      _loading = true;
      _failed = false;
    });
    List<CrossReference> references;
    try {
      references = await const CrossReferenceRepository().forVerse(
        book,
        chapter,
        verse,
        versionId: widget.sourceVersionId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _references = references;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sourceBookName == null
              ? 'Références croisées'
              : '${widget.sourceBookName} '
                  '${widget.sourceChapter}:${widget.sourceVerse}',
        ),
      ),
      body: Column(
        children: [
          if (widget.sourceBook == null) _searchFields(),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _searchFields() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _book,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Livre (1–66)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _chapter,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chapitre'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _verse,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(labelText: 'Verset'),
            ),
          ),
          IconButton(onPressed: _search, icon: const Icon(Icons.search)),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return const _CrossMessage('Impossible de charger les références.');
    }
    final references = _references;
    if (references == null) {
      return const _CrossMessage(
        'Sélectionnez un verset dans le lecteur biblique.',
      );
    }
    if (references.isEmpty) {
      return const _CrossMessage('Aucune référence associée à ce verset.');
    }
    return ListView.separated(
      itemCount: references.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final reference = references[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 6,
          ),
          title: Text(
            '${reference.bookName} '
            '${reference.chapter}:${reference.verseLabel}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            reference.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChapterReaderScreen(
                book: BibleBook(
                  id: reference.bookId,
                  name: reference.bookName,
                  abbreviation: '',
                  testament: '',
                  chaptersCount: reference.chaptersCount,
                ),
                initialChapter: reference.chapter,
                initialVerse: reference.verseStart,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CrossMessage extends StatelessWidget {
  final String text;

  const _CrossMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
