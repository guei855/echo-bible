import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/models/bible_version.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef VersionLoader = Future<List<BibleVersion>> Function();
typedef ChapterLoader = Future<List<Map<String, Object?>>> Function(
  int versionId,
);

class ParallelComparisonScreen extends StatelessWidget {
  final BibleBook book;
  final int chapter;
  final int verse;
  final int? verseEnd;
  final int? initialVersionId;

  const ParallelComparisonScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    this.verseEnd,
    this.initialVersionId,
  });

  @override
  Widget build(BuildContext context) {
    final end = verseEnd ?? verse;
    return Scaffold(
      appBar: AppBar(
        title: Text('${book.name} $chapter:${_rangeLabel(verse, end)}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: PassageComparisonView(
        bookId: book.id,
        chapter: chapter,
        verseStart: verse,
        verseEnd: end,
        initialVersionId: initialVersionId,
      ),
    );
  }
}

class PassageComparisonView extends StatefulWidget {
  final int bookId;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final int? initialVersionId;
  final VersionLoader? versionLoader;
  final ChapterLoader? chapterLoader;

  const PassageComparisonView({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    this.initialVersionId,
    this.versionLoader,
    this.chapterLoader,
  });

  @override
  State<PassageComparisonView> createState() => _PassageComparisonViewState();
}

class _PassageComparisonViewState extends State<PassageComparisonView> {
  static const _preferenceKey = 'comparison_preferred_version_ids';

  List<BibleVersion> _versions = const [];
  Set<int> _selectedIds = const {};
  List<_ComparedPassage> _passages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final versions = await (widget.versionLoader?.call() ??
        BibleVersionRepository.getInstalledVersions());
    final preferences = await SharedPreferences.getInstance();
    final savedIds = preferences
            .getStringList(_preferenceKey)
            ?.map(int.tryParse)
            .whereType<int>()
            .where((id) => versions.any((version) => version.id == id))
            .toSet() ??
        <int>{};
    final selectedIds = savedIds.isEmpty
        ? versions.map((version) => version.id).toSet()
        : savedIds;
    if (widget.initialVersionId case final initialId?
        when versions.any((version) => version.id == initialId)) {
      selectedIds.add(initialId);
    }
    if (!mounted) return;
    setState(() {
      _versions = versions;
      _selectedIds = selectedIds;
    });
    await _loadPassages();
  }

  Future<void> _loadPassages() async {
    if (_versions.isEmpty || _selectedIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _passages = const [];
        _loading = false;
      });
      return;
    }
    if (mounted) setState(() => _loading = true);
    final selectedVersions = _versions
        .where((version) => _selectedIds.contains(version.id))
        .toList();
    final passages = await Future.wait(
      selectedVersions.map((version) async {
        final rows = await (widget.chapterLoader?.call(version.id) ??
            BibleVersionRepository.getChapter(
              bookId: widget.bookId,
              chapterNumber: widget.chapter,
              versionId: version.id,
            ));
        final selectedRows = rows.where((row) {
          final number = row['verse_number'] as int;
          return number >= widget.verseStart && number <= widget.verseEnd;
        }).toList();
        return _ComparedPassage(
          version: version,
          verses: selectedRows,
          usesFallback: selectedRows.any(
            (row) => row['uses_default_text'] == 1,
          ),
        );
      }),
    );
    if (!mounted) return;
    setState(() {
      _passages = passages;
      _loading = false;
    });
  }

  Future<void> _chooseVersions() async {
    final draft = Set<int>.from(_selectedIds);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Versions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final version in _versions)
                  CheckboxListTile(
                    value: draft.contains(version.id),
                    title: Text(version.name),
                    subtitle: Text(version.abbreviation),
                    onChanged: (checked) => updateDialog(() {
                      if (checked == true) {
                        draft.add(version.id);
                      } else if (draft.length > 1) {
                        draft.remove(version.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _preferenceKey,
      result.map((id) => '$id').toList(),
    );
    if (!mounted) return;
    setState(() => _selectedIds = result);
    await _loadPassages();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_versions.isEmpty) {
      return const Center(
        child: Text('Aucune version biblique n\u2019est installée.'),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_passages.length} version(s) comparée(s)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('comparison-versions-button'),
                onPressed: _chooseVersions,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Versions'),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? _passages.length.clamp(1, 3)
                  : 1;
              return GridView.builder(
                key: const PageStorageKey('passage-comparison-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: columns == 1 ? null : 360,
                  childAspectRatio: columns == 1 ? 2.1 : 1,
                ),
                itemCount: _passages.length,
                itemBuilder: (context, index) =>
                    _PassageCard(passage: _passages[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PassageCard extends StatelessWidget {
  final _ComparedPassage passage;
  const _PassageCard({required this.passage});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${passage.version.abbreviation} — ${passage.version.name}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (passage.usesFallback)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Texte de la version par défaut utilisé pour les versets absents.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        for (final row in passage.verses) ...[
                          TextSpan(
                            text: '${row['verse_number']}  ',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: '${row['text'] ?? ''}\n'),
                        ],
                      ],
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ComparedPassage {
  final BibleVersion version;
  final List<Map<String, Object?>> verses;
  final bool usesFallback;

  const _ComparedPassage({
    required this.version,
    required this.verses,
    required this.usesFallback,
  });
}

String _rangeLabel(int start, int end) =>
    start == end ? '$start' : '$start-$end';
