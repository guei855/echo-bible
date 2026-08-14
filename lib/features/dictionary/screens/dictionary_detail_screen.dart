import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/widgets/study_destination_sheet.dart';
import 'package:flutter/material.dart';

class DictionaryDetailScreen extends StatelessWidget {
  final DictionaryEntry entry;

  const DictionaryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          IconButton(
            tooltip: 'Ajouter à une étude',
            onPressed: () => _addToStudy(context),
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SelectableText(
            entry.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 24),
          Text(
            'Dictionnaire de la Bible\nSous la direction de F. Vigouroux',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            [
              entry.source,
              if (entry.volume != null) 'Tome ${entry.volume}',
              if (entry.pageReference != null) 'p. ${entry.pageReference}',
              entry.sourceKind == 'wikisource_transcription'
                  ? 'Transcription Wikisource'
                  : 'Couche texte du fac-similé DjVu',
              entry.quality,
            ]
                .whereType<String>()
                .where((value) => value.trim().isNotEmpty)
                .join(' · '),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _addToStudy(BuildContext context) async {
    final displayMode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Référence de l’article'),
              onTap: () => Navigator.pop(context, 'reference'),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: const Text('Extrait'),
              onTap: () => Navigator.pop(context, 'excerpt'),
            ),
            ListTile(
              leading: const Icon(Icons.view_agenda_outlined),
              title: const Text('Bloc définition'),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (displayMode == null || !context.mounted) return;
    final now = DateTime.now();
    final excerpt = entry.content.length > 420
        ? '${entry.content.substring(0, 420)}…'
        : entry.content;
    final added = await StudyDestinationSheet.show(
      context,
      StudyBlock(
        id: '${now.microsecondsSinceEpoch}-dictionary',
        type: StudyBlockType.dictionary,
        position: 0,
        payload: {
          'entryId': entry.id,
          'title': entry.title,
          'excerpt': excerpt,
          'content': entry.content,
          'source': entry.source,
          'displayMode': displayMode,
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (context.mounted && added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Définition ajoutée à l’étude.')),
      );
    }
  }
}
