import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/study/models/commentary_entry.dart';
import 'package:echo_bible/features/study/repositories/commentary_repository.dart';
import 'package:echo_bible/shared/widgets/empty_resource_state.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
import 'package:flutter/material.dart';

class CommentaryScreen extends StatelessWidget {
  final int bookId;
  final int chapter;
  final int verse;
  final String reference;
  final String? verseText;
  final Future<bool>? availability;
  final Future<List<CommentaryEntry>>? entries;

  const CommentaryScreen({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.reference,
    this.verseText,
    this.availability,
    this.entries,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Commentaires — $reference')),
        body: FutureBuilder<bool>(
          future: availability ?? const CommentaryRepository().isAvailable(),
          builder: (context, availability) {
            if (availability.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (availability.data != true) {
              const manager = ResourceManager();
              return ResourceInstallCard(
                resource: manager.descriptor(OfflineResourceId.commentaries),
                state: OfflineResourceState.preparing,
                onLater: () => Navigator.maybePop(context),
              );
            }
            return FutureBuilder<List<CommentaryEntry>>(
              future: entries ??
                  const CommentaryRepository().forVerse(
                    bookId,
                    chapter,
                    verse,
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final values = snapshot.data ?? const [];
                if (values.isEmpty) {
                  return const EmptyResourceState(
                    icon: Icons.notes_rounded,
                    message: 'Aucun commentaire n’est indexé pour ce verset.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: values.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _PassageHeader(
                        reference: reference,
                        verseText: verseText,
                      );
                    }
                    final entry = values[index - 1];
                    return Card(
                      child: ExpansionTile(
                        initiallyExpanded: entry.content.length < 500,
                        title: Text(entry.workTitle),
                        subtitle: Text(entry.author),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(entry.content),
                          const SizedBox(height: 12),
                          Text(
                            '${entry.source}${entry.license == null ? '' : ' · ${entry.license}'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      );
}

class _PassageHeader extends StatelessWidget {
  final String reference;
  final String? verseText;

  const _PassageHeader({required this.reference, required this.verseText});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reference, style: Theme.of(context).textTheme.titleLarge),
          if (verseText case final text? when text.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(text, style: const TextStyle(height: 1.5)),
          ],
        ],
      );
}
