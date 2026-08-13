import 'package:flutter/material.dart';
import 'package:echo_bible/core/services/search_service.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/bible/services/strong_service.dart';
import 'package:echo_bible/features/search/widgets/highlighted_text.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';

class ConcordanceScreen extends StatefulWidget {
  final int initialTab;
  final String? initialQuery;

  const ConcordanceScreen({super.key, this.initialTab = 0, this.initialQuery});

  @override
  State<ConcordanceScreen> createState() => _ConcordanceScreenState();
}

class _ConcordanceScreenState extends State<ConcordanceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final TabController _tabController;
  List<SearchResultItem> _concordanceResults = [];
  List<StrongResultItem> _strongResults = [];
  String _query = '';
  String? _errorMessage;
  bool _isLoading = false;

  bool get _isStrongTab => _tabController.index == 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTab == 1 ? 1 : 0,
      vsync: this,
    )..addListener(() {
        if (!_tabController.indexIsChanging && mounted) setState(() {});
      });
    if (widget.initialQuery?.isNotEmpty ?? false) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      if (_isStrongTab) {
        final results = await StrongService.search(query);
        if (!mounted) return;
        setState(() {
          _strongResults = results;
          _isLoading = false;
        });
      } else {
        final results = await SearchService.searchExactVerses(query);
        if (!mounted) return;
        setState(() {
          _concordanceResults = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'La recherche est momentanément indisponible.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Étude biblique'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Concordance'),
            Tab(text: 'Strong'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: _isStrongTab
                    ? 'Code Strong, mot ou lemme'
                    : 'Mot ou expression à étudier',
                hintText: _isStrongTab ? 'Ex. H430 ou G26' : 'Ex. espérance',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Rechercher',
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _message(Icons.error_outline, _errorMessage!);
    }
    if (_query.isEmpty) {
      return _message(
        _isStrongTab ? Icons.translate_rounded : Icons.menu_book_rounded,
        _isStrongTab
            ? 'Recherchez un code Strong, un mot ou un lemme.'
            : 'Recherchez un mot pour retrouver tous les versets associés.',
      );
    }
    if (_isStrongTab) return _buildStrongResults();
    return _buildConcordanceResults();
  }

  Widget _buildConcordanceResults() {
    if (_concordanceResults.isEmpty) {
      return _message(
          Icons.search_off_rounded, 'Aucun verset trouvé pour « $_query ».');
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: ListView.separated(
        itemCount: _concordanceResults.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: colors.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final item = _concordanceResults[index];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              '${item.bookName} ${item.chapterNumber}:${item.verseNumber}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: HighlightedText(
                text: item.text,
                query: _query,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
                highlightColor: colors.tertiaryContainer,
              ),
            ),
            onTap: () => _openVerse(
              bookId: item.bookId,
              bookName: item.bookName,
              chaptersCount: item.chaptersCount,
              chapter: item.chapterNumber,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStrongResults() {
    if (_strongResults.isEmpty) {
      return _message(
        Icons.translate_outlined,
        'Aucune donnée Strong indexée pour « $_query ».',
      );
    }
    return ListView.separated(
      itemCount: _strongResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _strongResults[index];
        return ListTile(
          title: Text('${item.code} · ${item.lemma}'),
          subtitle: Text(
            [
              if (item.transliteration?.isNotEmpty ?? false)
                item.transliteration!,
              if (item.gloss?.isNotEmpty ?? false) item.gloss!,
              if (item.definition?.isNotEmpty ?? false) item.definition!,
            ].join('\n'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StrongWordScreen(
                word: VerseStrongWord(
                  id: 0,
                  order: 0,
                  word: item.lemma,
                  code: item.code,
                  lemma: item.lemma,
                  morphology: item.morphology,
                  language: item.language,
                  definition: item.definition,
                  transliteration: item.transliteration,
                  gloss: item.gloss,
                  source: item.source,
                  license: item.license,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _openVerse({
    required int bookId,
    required String bookName,
    required int chaptersCount,
    required int chapter,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: bookId,
            name: bookName,
            abbreviation: '',
            testament: '',
            chaptersCount: chaptersCount,
          ),
          initialChapter: chapter,
        ),
      ),
    );
  }
}
