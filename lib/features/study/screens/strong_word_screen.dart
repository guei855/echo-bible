import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/services/verse_study_service.dart';
import 'package:flutter/material.dart';

class StrongWordScreen extends StatelessWidget {
  final VerseStrongWord word;
  final Future<List<StrongOccurrence>>? occurrences;

  const StrongWordScreen({
    super.key,
    required this.word,
    this.occurrences,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${word.code} · ${word.word}')),
      body: FutureBuilder<List<StrongOccurrence>>(
        future: occurrences ?? VerseStudyService.loadOccurrences(word.code),
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
                        const SizedBox(height: 4),
                        Text(
                          word.word,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
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
                        _Field(label: 'Morphologie', value: word.morphology),
                        _Field(
                          label: 'Sens court (source)',
                          value: word.shortDefinition ?? word.gloss,
                        ),
                        _Field(
                          label: 'Définition lexicale (source)',
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
                            'Traduction française non disponible pour cette entrée.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${occurrences.length} occurrence${occurrences.length > 1 ? 's' : ''}',
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
                        child: Text(
                          occurrence.verseText,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openOccurrence(context, occurrence),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  String _numberKindLabel(StrongNumberKind kind) => switch (kind) {
        StrongNumberKind.classic => 'Strong classique',
        StrongNumberKind.extendedLexical => 'Extended Strong lexical',
        StrongNumberKind.extendedGrammar => 'Extended Strong grammatical',
      };

  void _openOccurrence(BuildContext context, StrongOccurrence occurrence) {
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
