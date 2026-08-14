import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:echo_bible/features/study/widgets/study_destination_sheet.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
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
  static const _pageSize = 20;
  final _book = TextEditingController();
  final _chapter = TextEditingController();
  final _verse = TextEditingController();
  final _repository = const CrossReferenceRepository();
  List<CrossReference>? _references;
  Object? _error;
  int _total = 0;
  int _limit = _pageSize;
  bool _loading = false;
  final Set<int> _selected = {};

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

  Future<void> _search({bool reset = true}) async {
    final book = int.tryParse(_book.text);
    final chapter = int.tryParse(_chapter.text);
    final verse = int.tryParse(_verse.text);
    if (book == null || chapter == null || verse == null) return;
    if (reset) _limit = _pageSize;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // sqflite uses a single instance per file path. Keep these operations
      // sequential so their intentionally short-lived handles cannot race.
      final total = await _repository.countForVerse(book, chapter, verse);
      final references = await _repository.forVerse(
        book,
        chapter,
        verse,
        limit: _limit,
        versionId: widget.sourceVersionId,
      );
      if (!mounted) return;
      setState(() {
        _references = references;
        _total = total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Références croisées')),
        body: Column(
          children: [
            if (widget.sourceBook == null) _searchFields(),
            Expanded(child: _content()),
          ],
        ),
        bottomNavigationBar: _selected.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: _addSelectedToStudy,
                    icon: const Icon(Icons.playlist_add),
                    label: Text(
                        'Ajouter ${_selected.length} référence${_selected.length > 1 ? 's' : ''} à une étude'),
                  ),
                ),
              ),
      );

  Widget _searchFields() => Padding(
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

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error is ResourceNotInstalledException) return _missingResource();
    if (_error != null) {
      return const _CrossMessage(
        'Impossible de charger les références croisées.',
      );
    }
    final references = _references;
    if (references == null) {
      return const _CrossMessage(
        'Sélectionnez un verset dans le lecteur biblique.',
      );
    }
    if (references.isEmpty) {
      return const _CrossMessage(
        'Aucune référence croisée n’a été trouvée pour ce verset.',
      );
    }
    return ListView.separated(
      itemCount: references.length + 2,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return _contextHeader();
        if (index == references.length + 1) return _moreButton(references);
        final reference = references[index - 1];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 6,
          ),
          leading: Checkbox(
            value: _selected.contains(index - 1),
            onChanged: (_) => setState(() {
              if (!_selected.add(index - 1)) _selected.remove(index - 1);
            }),
          ),
          title: Text(
            '${reference.bookName} '
            '${reference.chapter}:${reference.verseLabel}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reference.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (reference.usedLsgFallback)
                Text(
                  'Texte de secours : Louis Segond 1910',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
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
                initialVersionId: reference.requestedVersionId,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addSelectedToStudy() async {
    final references = _references ?? const <CrossReference>[];
    final chosen = _selected
        .where((index) => index >= 0 && index < references.length)
        .map((index) => references[index])
        .toList();
    if (chosen.isEmpty) return;
    final now = DateTime.now();
    final added = await StudyDestinationSheet.show(
      context,
      StudyBlock(
        id: '${now.microsecondsSinceEpoch}-cross-references',
        type: StudyBlockType.crossReferences,
        position: 0,
        payload: {
          'translationId': widget.sourceVersionId,
          'bookId': widget.sourceBook,
          'bookName': widget.sourceBookName,
          'chapter': widget.sourceChapter,
          'verseStart': widget.sourceVerse,
          'verseEnd': widget.sourceVerse,
          'reference': widget.sourceBookName == null
              ? null
              : '${widget.sourceBookName} ${widget.sourceChapter}:${widget.sourceVerse}',
          'references': chosen
              .map((item) =>
                  '${item.bookName} ${item.chapter}:${item.verseLabel} — ${item.text}')
              .toList(),
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (!mounted || !added) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Références ajoutées à l’étude.')),
    );
  }

  Widget _contextHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sourceBookName == null
                  ? 'Références associées'
                  : '${widget.sourceBookName} '
                      '${widget.sourceChapter}:${widget.sourceVerse}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
                '$_total passage${_total > 1 ? 's' : ''} lié${_total > 1 ? 's' : ''}'),
            Text(
              'OpenBible.info — ordre de pertinence',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _moreButton(List<CrossReference> references) {
    if (references.length >= _total) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: () {
          _limit += _pageSize;
          _search(reset: false);
        },
        icon: const Icon(Icons.expand_more),
        label: Text('Afficher plus (${_total - references.length})'),
      ),
    );
  }

  Widget _missingResource() {
    const manager = ResourceManager();
    final resource = manager.descriptor(OfflineResourceId.crossReferences);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Les références croisées ne sont pas encore installées. '
            'Cette ressource permet d’explorer les passages bibliques liés '
            'à votre verset.',
          ),
        ),
        ResourceInstallCard(
          resource: resource,
          state: OfflineResourceState.notInstalled,
          onDownload: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DownloadManagerScreen(
                  initialCategory: ResourceCategory.crossReferences,
                ),
              ),
            );
            if (mounted) _search();
          },
        ),
      ],
    );
  }
}

class _CrossMessage extends StatelessWidget {
  final String text;
  const _CrossMessage(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
