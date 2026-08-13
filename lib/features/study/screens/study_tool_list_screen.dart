import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/study/models/study_tool_item.dart';
import 'package:echo_bible/features/study/services/study_tools_service.dart';
import 'package:flutter/material.dart';

class StudyToolListScreen extends StatelessWidget {
  final StudyToolType type;
  final String title;

  const StudyToolListScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<StudyToolItem>>(
        future: StudyToolsService.loadItems(type),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.error_outline_rounded,
              text: 'Impossible de charger ces éléments.',
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _EmptyState(
              icon: _emptyIcon,
              text: _emptyText,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, index) => Divider(
              height: 1,
              color: colors.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                leading: _leading(item),
                title: Text(
                  '${item.bookName} ${item.chapterNumber}:${item.verseNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.title?.trim().isNotEmpty ?? false)
                        Text(
                          item.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (item.detail?.trim().isNotEmpty ?? false)
                        Text(
                          item.detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        item.verseText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontStyle: item.detail == null
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openItem(context, item),
              );
            },
          );
        },
      ),
    );
  }

  Widget _leading(StudyToolItem item) {
    if (type == StudyToolType.highlights) {
      return CircleAvatar(backgroundColor: _highlightColor(item.color));
    }
    return CircleAvatar(
      backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
      foregroundColor: AppColors.primary,
      child: Icon(
        switch (type) {
          StudyToolType.notes => Icons.edit_note_rounded,
          StudyToolType.highlights => Icons.brush_rounded,
          StudyToolType.bookmarks => Icons.bookmark_rounded,
          StudyToolType.history => Icons.history_rounded,
        },
      ),
    );
  }

  Color _highlightColor(String? color) => switch (color) {
        'yellow' => Colors.amber,
        'green' => Colors.green,
        'pink' => Colors.pink,
        'blue' => Colors.lightBlue,
        _ => AppColors.secondary,
      };

  IconData get _emptyIcon => switch (type) {
        StudyToolType.notes => Icons.edit_note_outlined,
        StudyToolType.highlights => Icons.brush_outlined,
        StudyToolType.bookmarks => Icons.bookmark_border_rounded,
        StudyToolType.history => Icons.history_rounded,
      };

  String get _emptyText => switch (type) {
        StudyToolType.notes => 'Aucune note personnelle pour le moment.',
        StudyToolType.highlights => 'Aucun verset surligné pour le moment.',
        StudyToolType.bookmarks => 'Aucun signet pour le moment.',
        StudyToolType.history => 'Aucun passage récent pour le moment.',
      };

  void _openItem(BuildContext context, StudyToolItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: item.bookId,
            name: item.bookName,
            abbreviation: '',
            testament: '',
            chaptersCount: item.chaptersCount,
          ),
          initialChapter: item.chapterNumber,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
