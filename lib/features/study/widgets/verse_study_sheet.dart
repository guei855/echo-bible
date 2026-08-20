import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/bible/screens/parallel_comparison_screen.dart';
import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/screens/commentary_screen.dart';
import 'package:echo_bible/features/study/screens/cross_references_screen.dart';
import 'package:echo_bible/features/study/screens/nave_topics_screen.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';
import 'package:echo_bible/features/search/screens/concordance_screen.dart';
import 'package:echo_bible/features/study/services/verse_study_service.dart';
import 'package:echo_bible/shared/widgets/empty_resource_state.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
import 'package:flutter/material.dart';

typedef StudyChapterLoader = Future<List<VerseStudyTarget>> Function(
  int bookId,
  int chapter,
  int versionId,
);
typedef StudyBooksLoader = Future<List<BibleBook>> Function(int versionId);
typedef StudyCrossReferenceLoader = Future<List<CrossReference>> Function(
  int bookId,
  int chapter,
  int verse,
  int versionId,
);

class VerseStudyTarget {
  final int verseId;
  final int verseNumber;
  final String verseText;

  const VerseStudyTarget({
    required this.verseId,
    required this.verseNumber,
    required this.verseText,
  });
}

class VerseStudyReference {
  final BibleBook book;
  final int chapter;
  final VerseStudyTarget target;

  const VerseStudyReference({
    required this.book,
    required this.chapter,
    required this.target,
  });
}

enum VerseStudyTool {
  concordance,
  lexicon,
  dictionary,
  topics,
  references,
  commentaries,
  compare,
}

class VerseStudySheet extends StatefulWidget {
  final BibleBook book;
  final int chapter;
  final int versionId;
  final List<VerseStudyTarget> verses;
  final int initialVerseNumber;
  final int? selectedVerseStart;
  final int? selectedVerseEnd;
  final String? selectedText;
  final int? selectedTextStart;
  final int? selectedTextEnd;
  final Future<VerseStudyData> Function(int verseId)? loadStudy;
  final StudyChapterLoader? loadChapter;
  final StudyBooksLoader? loadBooks;
  final StudyCrossReferenceLoader? loadReferences;
  final VersionLoader? comparisonVersionLoader;
  final ChapterLoader? comparisonChapterLoader;
  final NaveRepository naveRepository;

  const VerseStudySheet({
    super.key,
    required this.book,
    required this.chapter,
    required this.versionId,
    required this.verses,
    required this.initialVerseNumber,
    this.selectedVerseStart,
    this.selectedVerseEnd,
    this.selectedText,
    this.selectedTextStart,
    this.selectedTextEnd,
    this.loadStudy,
    this.loadChapter,
    this.loadBooks,
    this.loadReferences,
    this.comparisonVersionLoader,
    this.comparisonChapterLoader,
    this.naveRepository = const NaveRepository(),
  });

  static Future<void> show(
    BuildContext context, {
    required BibleBook book,
    required int chapter,
    required int versionId,
    required List<VerseStudyTarget> verses,
    required int initialVerseNumber,
    int? selectedVerseStart,
    int? selectedVerseEnd,
    String? selectedText,
    int? selectedTextStart,
    int? selectedTextEnd,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseStudySheet(
        book: book,
        chapter: chapter,
        versionId: versionId,
        verses: verses,
        initialVerseNumber: initialVerseNumber,
        selectedVerseStart: selectedVerseStart,
        selectedVerseEnd: selectedVerseEnd,
        selectedText: selectedText,
        selectedTextStart: selectedTextStart,
        selectedTextEnd: selectedTextEnd,
      ),
    );
  }

  @override
  State<VerseStudySheet> createState() => _VerseStudySheetState();
}

class _VerseStudySheetState extends State<VerseStudySheet> {
  late int _index;
  late List<VerseStudyTarget> _chapterVerses;
  late VerseStudyReference _currentReference;
  VerseStudyTool _tool = VerseStudyTool.lexicon;
  late Future<VerseStudyData> _study;
  int _navigationGeneration = 0;
  bool _isInitialReference = true;

  BibleBook get _book => _currentReference.book;
  int get _chapter => _currentReference.chapter;
  VerseStudyTarget get _verse => _currentReference.target;
  String get _reference => '${_book.name} $_chapter:${_verse.verseNumber}';

  @override
  void initState() {
    super.initState();
    _chapterVerses = widget.verses;
    final initialIndex = _chapterVerses.indexWhere(
      (verse) => verse.verseNumber == widget.initialVerseNumber,
    );
    _index = initialIndex < 0 ? 0 : initialIndex;
    _currentReference = VerseStudyReference(
      book: widget.book,
      chapter: widget.chapter,
      target: _chapterVerses[_index],
    );
    _study = _loadStudy();
  }

  Future<VerseStudyData> _loadStudy() =>
      widget.loadStudy?.call(_verse.verseId) ??
      VerseStudyService.loadVerse(
        _verse.verseId,
        selectedText: _isInitialReference ? widget.selectedText : null,
      );

  Future<void> _move(int delta) async {
    final next = _index + delta;
    if (next >= 0 && next < _chapterVerses.length) {
      _setCurrentReference(_book, _chapter, next);
      return;
    }
    await _moveAcrossChapter(delta);
  }

  void _setCurrentReference(BibleBook book, int chapter, int index) {
    _navigationGeneration++;
    setState(() {
      _index = index;
      _currentReference = VerseStudyReference(
        book: book,
        chapter: chapter,
        target: _chapterVerses[index],
      );
      _isInitialReference = false;
      _study = _loadStudy();
    });
  }

  Future<void> _moveAcrossChapter(int delta) async {
    var targetBook = _book;
    var targetChapter = _chapter + delta;
    if (targetChapter < 1 || targetChapter > targetBook.chaptersCount) {
      final targetBookId = targetBook.id + delta;
      if (targetBookId < 1 || targetBookId > 66) return;
      final books = await (widget.loadBooks?.call(widget.versionId) ??
          BibleVersionRepository.getBooks(versionId: widget.versionId));
      if (!mounted) return;
      final matches = books.where((book) => book.id == targetBookId);
      if (matches.isEmpty) return;
      targetBook = matches.first;
      targetChapter = delta > 0 ? 1 : targetBook.chaptersCount;
    }
    final generation = ++_navigationGeneration;
    final verses = await (widget.loadChapter?.call(
          targetBook.id,
          targetChapter,
          widget.versionId,
        ) ??
        _loadChapter(targetBook.id, targetChapter));
    if (!mounted || generation != _navigationGeneration || verses.isEmpty) {
      return;
    }
    final index = delta > 0 ? 0 : verses.length - 1;
    setState(() {
      _chapterVerses = verses;
      _index = index;
      _currentReference = VerseStudyReference(
        book: targetBook,
        chapter: targetChapter,
        target: verses[index],
      );
      _isInitialReference = false;
      _study = _loadStudy();
    });
  }

  Future<List<VerseStudyTarget>> _loadChapter(
    int bookId,
    int chapter,
  ) async {
    final rows = await BibleVersionRepository.getChapter(
      bookId: bookId,
      chapterNumber: chapter,
      versionId: widget.versionId,
    );
    return rows
        .map(
          (row) => VerseStudyTarget(
            verseId: row['id'] as int,
            verseNumber: row['verse_number'] as int,
            verseText: row['text'] as String? ?? '',
          ),
        )
        .toList();
  }

  bool get _canMovePrevious => _index > 0 || _chapter > 1 || _book.id > 1;
  bool get _canMoveNext =>
      _index < _chapterVerses.length - 1 ||
      _chapter < _book.chaptersCount ||
      _book.id < 66;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: .92,
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reference,
                          key: const Key('verse-study-reference'),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _isInitialReference &&
                                  widget.selectedText?.isNotEmpty == true
                              ? '« ${widget.selectedText} »'
                              : _verse.verseText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _toolChip(
                    VerseStudyTool.concordance,
                    Icons.manage_search_rounded,
                    'Concordance',
                  ),
                  _toolChip(VerseStudyTool.lexicon, Icons.translate, 'Lexique'),
                  _toolChip(
                    VerseStudyTool.dictionary,
                    Icons.menu_book_outlined,
                    'Dictionnaire',
                  ),
                  _toolChip(
                      VerseStudyTool.topics, Icons.hub_outlined, 'Thèmes'),
                  _toolChip(
                    VerseStudyTool.references,
                    Icons.account_tree_outlined,
                    'Références',
                  ),
                  _toolChip(
                    VerseStudyTool.commentaries,
                    Icons.chat_bubble_outline,
                    'Commentaires',
                  ),
                  _toolChip(
                    VerseStudyTool.compare,
                    Icons.compare_arrows,
                    'Comparer',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(child: _toolContent()),
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _canMovePrevious ? () => _move(-1) : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Verset précédent'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _canMoveNext ? () => _move(1) : null,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Verset suivant'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolChip(VerseStudyTool tool, IconData icon, String label) {
    final selected = _tool == tool;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: Key('study-tool-${tool.name}'),
        selected: selected,
        onSelected: (_) => setState(() => _tool = tool),
        avatar: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _toolContent() => switch (_tool) {
        VerseStudyTool.concordance => _ConcordancePanel(
            selectedText: _isInitialReference
                ? widget.selectedText ?? _verse.verseText
                : _verse.verseText,
          ),
        VerseStudyTool.lexicon => _LexiconPanel(
            study: _study,
            versionId: widget.versionId,
          ),
        VerseStudyTool.dictionary => const _DictionaryPanel(),
        VerseStudyTool.topics => _TopicsPanel(
            bookId: _book.id,
            chapter: _chapter,
            verse: _verse.verseNumber,
            searchQuery: _isInitialReference ? widget.selectedText : null,
            repository: widget.naveRepository,
          ),
        VerseStudyTool.references => _ReferencesPanel(
            book: _book,
            chapter: _chapter,
            verse: _verse.verseNumber,
            versionId: widget.versionId,
            loader: widget.loadReferences,
          ),
        VerseStudyTool.commentaries => _CommentaryPanel(
            bookId: _book.id,
            chapter: _chapter,
            verse: _verse.verseNumber,
            reference: _reference,
            verseText: _verse.verseText,
          ),
        VerseStudyTool.compare => _ComparisonPanel(
            book: _book,
            chapter: _chapter,
            verse: _verse.verseNumber,
            initialVersionId: widget.versionId,
            versionLoader: widget.comparisonVersionLoader,
            chapterLoader: widget.comparisonChapterLoader,
          ),
      };
}

class _ConcordancePanel extends StatelessWidget {
  final String selectedText;

  const _ConcordancePanel({required this.selectedText});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.manage_search_rounded, size: 48),
              const SizedBox(height: 14),
              Text(
                selectedText.trim().split(RegExp(r'\s+')).length == 1
                    ? 'Retrouvez toutes les occurrences exactes de ce mot.'
                    : 'Recherchez cette expression dans le texte biblique.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConcordanceScreen(
                      initialQuery: selectedText,
                    ),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Ouvrir la concordance'),
              ),
            ],
          ),
        ),
      );
}

class _LexiconPanel extends StatelessWidget {
  final Future<VerseStudyData> study;
  final int versionId;
  const _LexiconPanel({required this.study, required this.versionId});

  @override
  Widget build(BuildContext context) => FutureBuilder<VerseStudyData>(
        future: study,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (snapshot.error is ResourceNotInstalledException) {
              const manager = ResourceManager();
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text('Le lexique Strong n’est pas installé.'),
                  const SizedBox(height: 10),
                  ResourceInstallCard(
                    resource: manager.descriptor(OfflineResourceId.strong),
                    state: OfflineResourceState.notInstalled,
                    onDownload: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadManagerScreen(
                          initialCategory: ResourceCategory.strong,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const EmptyResourceState(
              icon: Icons.error_outline,
              message: 'Impossible de charger le lexique de ce verset.',
            );
          }
          final words = snapshot.data?.strongWords ?? const [];
          if (words.isEmpty) {
            return const EmptyResourceState(
              icon: Icons.text_snippet_outlined,
              message: 'Aucun terme Strong n’est indexé pour ce verset.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Text(
                'Alignement Strong basé sur la Segond 1910. Chaque association '
                'vient du jeu de données français, sans traduction inventée.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final word in words)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    title: Text(
                      '${word.word} · ${word.code}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      [
                        word.lemma == null ? null : 'Lemme : ${word.lemma}',
                        word.originalWord == null
                            ? null
                            : 'Mot original : ${word.originalWord}',
                        word.transliteration == null
                            ? null
                            : 'Translittération : ${word.transliteration}',
                        word.pronunciation == null
                            ? null
                            : 'Prononciation : ${word.pronunciation}',
                        word.morphologyInFrench == null
                            ? null
                            : 'Morphologie : ${word.morphologyInFrench}',
                        word.frenchDefinition ??
                            word.shortDefinition ??
                            word.definition,
                      ].whereType<String>().join('\n'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StrongWordScreen(
                          word: word,
                          initialVersionId: versionId,
                        ),
                        settings: const RouteSettings(name: 'strong-entry'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _DictionaryPanel extends StatelessWidget {
  const _DictionaryPanel();

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: const DictionaryRepository().isAvailable(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            const manager = ResourceManager();
            final resource = manager.descriptor(OfflineResourceId.dictionary);
            return FutureBuilder<OfflineResourceState>(
              future: manager.state(OfflineResourceId.dictionary),
              builder: (context, state) => ResourceInstallCard(
                resource: resource,
                state: state.data ?? OfflineResourceState.preparing,
                onLater: () => Navigator.pop(context),
              ),
            );
          }
          return EmptyResourceState(
            icon: Icons.menu_book_outlined,
            message: 'Recherchez un article dans le dictionnaire français.',
            actionLabel: 'Ouvrir le dictionnaire',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DictionaryScreen()),
            ),
          );
        },
      );
}

class _TopicsPanel extends StatelessWidget {
  final int bookId;
  final int chapter;
  final int verse;
  final String? searchQuery;
  final NaveRepository repository;

  const _TopicsPanel({
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.searchQuery,
    required this.repository,
  });

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NaveTopicsScreen(initialQuery: searchQuery),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NaveTopic>>(
        future: repository.forVerse(bookId, chapter, verse),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final missing = snapshot.error is ResourceNotInstalledException;
            return EmptyResourceState(
              icon: missing
                  ? Icons.download_for_offline_outlined
                  : Icons.error_outline,
              message: missing
                  ? 'Nave n’est pas installé.'
                  : 'Impossible de charger les thèmes de Nave.',
              actionLabel: missing ? 'Télécharger' : null,
              onAction: missing
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadManagerScreen(
                            initialCategory: ResourceCategory.nave,
                          ),
                        ),
                      )
                  : null,
            );
          }
          final topics = snapshot.data ?? const [];
          if (topics.isEmpty) {
            return EmptyResourceState(
              icon: Icons.hub_outlined,
              message: 'Aucun thème Nave n’est directement relié à ce verset.',
              actionLabel: searchQuery?.trim().isNotEmpty == true
                  ? 'Rechercher « ${searchQuery!.trim()} » dans Nave'
                  : 'Rechercher dans Nave',
              onAction: () => _openSearch(context),
            );
          }
          return Column(
            children: [
              if (searchQuery?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('search-selected-text-in-nave'),
                      onPressed: () => _openSearch(context),
                      icon: const Icon(Icons.search),
                      label: Text(
                        'Rechercher « ${searchQuery!.trim()} » dans Nave',
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: topics.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.hub_outlined),
                    title: Text(topics[index].title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            NaveTopicDetailScreen(topic: topics[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _ReferencesPanel extends StatefulWidget {
  final BibleBook book;
  final int chapter;
  final int verse;
  final int versionId;
  final StudyCrossReferenceLoader? loader;

  const _ReferencesPanel({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.versionId,
    this.loader,
  });

  @override
  State<_ReferencesPanel> createState() => _ReferencesPanelState();
}

class _ReferencesPanelState extends State<_ReferencesPanel> {
  late Future<List<CrossReference>> _references;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _ReferencesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.chapter != widget.chapter ||
        oldWidget.verse != widget.verse ||
        oldWidget.versionId != widget.versionId) {
      setState(_reload);
    }
  }

  void _reload() {
    final generation = ++_requestGeneration;
    final request = widget.loader?.call(
          widget.book.id,
          widget.chapter,
          widget.verse,
          widget.versionId,
        ) ??
        const CrossReferenceRepository().forVerse(
          widget.book.id,
          widget.chapter,
          widget.verse,
          versionId: widget.versionId,
        );
    _references = request.then(
      (references) => generation == _requestGeneration
          ? references
          : const <CrossReference>[],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CrossReference>>(
        future: _references,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (snapshot.error is ResourceNotInstalledException) {
              const manager = ResourceManager();
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Les références croisées ne sont pas encore installées. '
                      'Cette ressource permet d’explorer les passages '
                      'bibliques liés à votre verset.',
                    ),
                  ),
                  ResourceInstallCard(
                    resource: manager.descriptor(
                      OfflineResourceId.crossReferences,
                    ),
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
                      if (!mounted) return;
                      setState(_reload);
                    },
                  ),
                ],
              );
            }
            return const EmptyResourceState(
              icon: Icons.error_outline,
              message: 'Impossible de charger les références croisées.',
            );
          }
          final references = snapshot.data ?? const [];
          if (references.isEmpty) {
            return const EmptyResourceState(
              icon: Icons.link_off,
              message:
                  'Aucune référence croisée n’a été trouvée pour ce verset.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: references.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == references.length) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CrossReferencesScreen(
                          sourceBook: widget.book.id,
                          sourceBookName: widget.book.name,
                          sourceChapter: widget.chapter,
                          sourceVerse: widget.verse,
                          sourceVersionId: widget.versionId,
                        ),
                      ),
                    ),
                    child: const Text('Afficher toutes les références'),
                  ),
                );
              }
              final reference = references[index];
              return ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(
                  '${reference.bookName} '
                  '${reference.chapter}:${reference.verseLabel}',
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
                      initialVersionId: reference.requestedVersionId,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
}

class _CommentaryPanel extends StatelessWidget {
  final int bookId;
  final int chapter;
  final int verse;
  final String reference;
  final String verseText;

  const _CommentaryPanel({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.reference,
    required this.verseText,
  });

  @override
  Widget build(BuildContext context) {
    const manager = ResourceManager();
    return FutureBuilder<OfflineResourceState>(
      future: manager.state(OfflineResourceId.commentaries),
      builder: (context, snapshot) {
        final state = snapshot.data ?? OfflineResourceState.preparing;
        if (state != OfflineResourceState.installed) {
          return ResourceInstallCard(
            resource: manager.descriptor(OfflineResourceId.commentaries),
            state: state,
          );
        }
        return EmptyResourceState(
          icon: Icons.chat_bubble_outline,
          message: 'Consultez les commentaires disponibles pour ce verset.',
          actionLabel: 'Lire les commentaires',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommentaryScreen(
                bookId: bookId,
                chapter: chapter,
                verse: verse,
                reference: reference,
                verseText: verseText,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  final BibleBook book;
  final int chapter;
  final int verse;
  final int initialVersionId;
  final VersionLoader? versionLoader;
  final ChapterLoader? chapterLoader;

  const _ComparisonPanel({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.initialVersionId,
    this.versionLoader,
    this.chapterLoader,
  });

  @override
  Widget build(BuildContext context) => PassageComparisonView(
        bookId: book.id,
        chapter: chapter,
        verseStart: verse,
        verseEnd: verse,
        initialVersionId: initialVersionId,
        versionLoader: versionLoader,
        chapterLoader: chapterLoader,
      );
}
