import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:flutter/material.dart';

class DictionaryDetailScreen extends StatelessWidget {
  final DictionaryEntry entry;

  const DictionaryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SelectableText(
            entry.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 24),
          Text(
            [entry.author, entry.source]
                .whereType<String>()
                .where((value) => value.trim().isNotEmpty)
                .join(' · '),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
