import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/services/verse_study_service.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/widgets/study_destination_sheet.dart';
import 'package:flutter/material.dart';

class StrongWordScreen extends StatefulWidget {
  final VerseStrongWord word;
  final Future<List<StrongOccurrence>>? occurrences;
  final Future<List<StrongOccurrence>> Function(int limit, int offset)?
      occurrenceLoader;
  final ValueChanged<StrongOccurrence>? onOpenOccurrence;
  final int? initialVersionId;

  const StrongWordScreen({
    super.key,
    required this.word,
    this.occurrences,
    this.occurrenceLoader,
    this.onOpenOccurrence,
    this.initialVersionId,
  });

  @override
  State<StrongWordScreen> createState() => _StrongWordScreenState();
}

class _StrongWordScreenState extends State<StrongWordScreen> {
  static const _pageSize = 30;
  late Future<List<StrongOccurrence>> _occurrences;
  bool _hasMore = true;

  VerseStrongWord get word => widget.word;

  @override
  void initState() {
    super.initState();
    if (widget.occurrences != null) {
      _occurrences = widget.occurrences!;
      _hasMore = false;
    } else {
      _occurrences = _loadOccurrences(0).then((items) {
        _hasMore = items.length == _pageSize;
        return items;
      });
    }
  }

  void _loadMore(List<StrongOccurrence> current) {
    setState(() {
      _occurrences = _loadOccurrences(current.length).then((next) {
        _hasMore = next.length == _pageSize;
        return [...current, ...next];
      });
    });
  }

  Future<List<StrongOccurrence>> _loadOccurrences(int offset) =>
      widget.occurrenceLoader?.call(_pageSize, offset) ??
      VerseStudyService.loadOccurrences(
        word.code,
        limit: _pageSize,
        offset: offset,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${word.code} · ${word.word}'),
        actions: [
          IconButton(
            tooltip: 'Ajouter à une étude',
            onPressed: _addToStudy,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: FutureBuilder<List<StrongOccurrence>>(
        future: _occurrences,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _Message(
              icon: Icons.error_outline,
              text: 'Impossible de charger cette entrée Strong.',
            );
          }
          final occurrences = snapshot.data ?? const [];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.code,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Directionality(
                          textDirection: word.inferredLanguage == 'Hébreu'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: SelectableText(
                            word.originalWord ?? word.lemma ?? word.word,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (word.word != (word.originalWord ?? word.lemma))
                          _Field(label: 'Mot français', value: word.word),
                        _Field(label: 'Lemme', value: word.lemma),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(word.inferredLanguage)),
                            Chip(
                                label: Text(_numberKindLabel(word.numberKind))),
                          ],
                        ),
                        _Field(
                          label: 'Translittération',
                          value: word.transliteration,
                        ),
                        _Field(
                          label: 'Prononciation',
                          value: word.pronunciation,
                        ),
                        _Field(
                          label: 'Morphologie',
                          value: word.morphologyInFrench,
                        ),
                        _Field(
                          label: 'Sens court (source)',
                          value: word.shortDefinition ?? word.gloss,
                        ),
                        _Field(
                          label: 'Définition de la source (anglais)',
                          value: word.definition,
                        ),
                        if (word.frenchDefinition?.trim().isNotEmpty ?? false)
                          _Field(
                            label: 'Définition française',
                            value: word.frenchDefinition,
                          ),
                        if (word.source?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Source : ${word.source} · ${word.license ?? 'CC BY 4.0'} · STEPBible.org',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                          ),
                        ],
                        if (word.frenchDefinition?.trim().isEmpty ?? true) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Définition française non disponible dans les ressources installées.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                        ],
                        _Field(
                          label: 'Détails techniques — morphologie brute',
                          value: word.morphology,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Occurrences dans le texte original · '
                    '${occurrences.length} affichée${occurrences.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              if (occurrences.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    icon: Icons.search_off_rounded,
                    text: 'Aucune occurrence trouvée.',
                  ),
                )
              else
                SliverList.separated(
                  itemCount: occurrences.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: colors.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final occurrence = occurrences[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      title: Text(
                        '${occurrence.bookName} ${occurrence.chapterNumber}:${occurrence.verseNumber}',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (occurrence.originalForm.isNotEmpty)
                              Directionality(
                                textDirection: word.inferredLanguage == 'Hébreu'
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                child: Text(
                                  occurrence.originalForm,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (occurrence.morphology?.isNotEmpty ?? false)
                              Text(
                                occurrence.morphologyDescription ??
                                    VerseStrongWord(
                                      id: 0,
                                      order: 0,
                                      word: occurrence.originalForm,
                                      code: word.code,
                                      morphology: occurrence.morphology,
                                    ).morphologyInFrench ??
                                    occurrence.morphology!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 3),
                            Text(
                              occurrence.verseText,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openOccurrence(context, occurrence),
                    );
                  },
                ),
              if (occurrences.isNotEmpty && _hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: () => _loadMore(occurrences),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Afficher plus'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addToStudy() async {
    final displayMode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Lien Strong'),
              onTap: () => Navigator.pop(context, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.view_agenda_outlined),
              title: const Text('Bloc Strong complet'),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (displayMode == null || !mounted) return;
    final now = DateTime.now();
    final study = await StudyDestinationSheet.show(
      context,
      StudyBlock(
        id: '${now.microsecondsSinceEpoch}-strong',
        type: StudyBlockType.strong,
        position: 0,
        payload: {
          'code': word.code,
          'originalWord': word.originalWord ?? word.lemma ?? word.word,
          'transliteration': word.transliteration,
          'definition': word.frenchDefinition ??
              word.shortDefinition ??
              word.definition ??
              '',
          'language': word.inferredLanguage,
          'displayMode': displayMode,
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (mounted && study != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrée Strong ajoutée à l’étude.')),
      );
    }
  }

  String _numberKindLabel(StrongNumberKind kind) => switch (kind) {
        StrongNumberKind.classic => 'Strong classique',
        StrongNumberKind.extendedLexical => 'Extended Strong lexical',
        StrongNumberKind.extendedGrammar => 'Extended Strong grammatical',
      };

  void _openOccurrence(BuildContext context, StrongOccurrence occurrence) {
    if (widget.onOpenOccurrence != null) {
      widget.onOpenOccurrence!(occurrence);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: occurrence.bookId,
            name: occurrence.bookName,
            abbreviation: '',
            testament: '',
            chaptersCount: occurrence.chaptersCount,
          ),
          initialChapter: occurrence.chapterNumber,
          initialVerse: occurrence.verseNumber,
          initialVersionId: widget.initialVersionId,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final hasValue = value?.trim().isNotEmpty ?? false;
    if (!hasValue) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        SelectableText(value!),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
