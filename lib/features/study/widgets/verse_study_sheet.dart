import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/bible/screens/parallel_comparison_screen.dart';
import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_screen.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/screens/commentary_screen.dart';
import 'package:echo_bible/features/study/screens/nave_topics_screen.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';
import 'package:echo_bible/features/search/screens/concordance_screen.dart';
import 'package:echo_bible/features/study/services/verse_study_service.dart';
import 'package:echo_bible/shared/widgets/empty_resource_state.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
import 'package:flutter/material.dart';

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
  VerseStudyTool _tool = VerseStudyTool.lexicon;
  late Future<VerseStudyData> _study;

  VerseStudyTarget get _verse => widget.verses[_index];
  String get _reference =>
      '${widget.book.name} ${widget.chapter}:${_verse.verseNumber}';

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.verses.indexWhere(
      (verse) => verse.verseNumber == widget.initialVerseNumber,
    );
    _index = initialIndex < 0 ? 0 : initialIndex;
    _study = _loadStudy();
  }

  Future<VerseStudyData> _loadStudy() =>
      widget.loadStudy?.call(_verse.verseId) ??
      VerseStudyService.loadVerse(_verse.verseId);

  void _move(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.verses.length) return;
    setState(() {
      _index = next;
      _study = _loadStudy();
    });
  }

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
                      onPressed: _index == 0 ? null : () => _move(-1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Verset précédent'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _index == widget.verses.length - 1
                          ? null
                          : () => _move(1),
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
            selectedText: widget.selectedText ?? _verse.verseText,
          ),
        VerseStudyTool.lexicon => _LexiconPanel(study: _study),
        VerseStudyTool.dictionary => const _DictionaryPanel(),
        VerseStudyTool.topics => _TopicsPanel(
            bookId: widget.book.id,
            chapter: widget.chapter,
            verse: _verse.verseNumber,
          ),
        VerseStudyTool.references => _ReferencesPanel(study: _study),
        VerseStudyTool.commentaries => _CommentaryPanel(
            bookId: widget.book.id,
            chapter: widget.chapter,
            verse: _verse.verseNumber,
            reference: _reference,
            verseText: _verse.verseText,
          ),
        VerseStudyTool.compare => _ComparisonPanel(
            book: widget.book,
            chapter: widget.chapter,
            verse: _verse.verseNumber,
            verseEnd: widget.selectedVerseEnd,
            selectedVerseStart: widget.selectedVerseStart,
            initialVersionId: widget.versionId,
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
  const _LexiconPanel({required this.study});

  @override
  Widget build(BuildContext context) => FutureBuilder<VerseStudyData>(
        future: study,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
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
                'Termes originaux réellement associés au verset. Ils ne sont '
                'pas alignés artificiellement avec les mots français.',
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
                        word.transliteration == null
                            ? null
                            : 'Translittération : ${word.transliteration}',
                        word.pronunciation == null
                            ? null
                            : 'Prononciation : ${word.pronunciation}',
                        word.morphology == null
                            ? null
                            : 'Morphologie : ${word.morphology}',
                        word.frenchDefinition ??
                            word.shortDefinition ??
                            word.definition,
                      ].whereType<String>().join('\n'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StrongWordScreen(word: word),
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

  const _TopicsPanel({
    required this.bookId,
    required this.chapter,
    required this.verse,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NaveTopic>>(
        future: const NaveRepository().forVerse(bookId, chapter, verse),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyResourceState(
              icon: Icons.error_outline,
              message: 'Impossible de charger les thèmes de Nave.',
            );
          }
          final topics = snapshot.data ?? const [];
          if (topics.isEmpty) {
            return EmptyResourceState(
              icon: Icons.hub_outlined,
              message: 'Aucun thème Nave n’est directement relié à ce verset.',
              actionLabel: 'Rechercher un thème',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NaveTopicsScreen()),
              ),
            );
          }
          return ListView.separated(
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
                  builder: (_) => NaveTopicDetailScreen(topic: topics[index]),
                ),
              ),
            ),
          );
        },
      );
}

class _ReferencesPanel extends StatelessWidget {
  final Future<VerseStudyData> study;
  const _ReferencesPanel({required this.study});

  @override
  Widget build(BuildContext context) => FutureBuilder<VerseStudyData>(
        future: study,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyResourceState(
              icon: Icons.error_outline,
              message: 'Impossible de charger les références croisées.',
            );
          }
          final references = snapshot.data?.crossReferences ?? const [];
          if (references.isEmpty) {
            return const EmptyResourceState(
              icon: Icons.link_off,
              message: 'Aucune référence croisée n’est indexée pour ce verset.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: references.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
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
                trailing: reference.score == null
                    ? const Icon(Icons.chevron_right)
                    : Chip(label: Text('${reference.score}')),
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
  final int? verseEnd;
  final int? selectedVerseStart;
  final int initialVersionId;

  const _ComparisonPanel({
    required this.book,
    required this.chapter,
    required this.verse,
    this.verseEnd,
    this.selectedVerseStart,
    required this.initialVersionId,
  });

  @override
  Widget build(BuildContext context) => PassageComparisonView(
        bookId: book.id,
        chapter: chapter,
        verseStart: selectedVerseStart ?? verse,
        verseEnd: verseEnd ?? selectedVerseStart ?? verse,
        initialVersionId: initialVersionId,
      );
}
