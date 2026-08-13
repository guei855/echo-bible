import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:flutter/material.dart';

class BookChapterSelection {
  final BibleBook book;
  final int chapter;

  const BookChapterSelection({required this.book, required this.chapter});
}

class BookChapterSelectorSheet extends StatefulWidget {
  final int currentBookId;
  final int currentChapter;
  final List<BibleBook>? initialBooks;

  const BookChapterSelectorSheet({
    super.key,
    required this.currentBookId,
    required this.currentChapter,
    this.initialBooks,
  });

  static Future<BookChapterSelection?> show(
    BuildContext context, {
    required int currentBookId,
    required int currentChapter,
    required bool darkMode,
    List<BibleBook>? initialBooks,
  }) {
    final brightness = darkMode ? Brightness.dark : Brightness.light;
    final sheetTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(
        primary: darkMode ? AppColors.secondary : AppColors.primary,
        onPrimary: Colors.white,
        surface: darkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        onSurface:
            darkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        onSurfaceVariant: darkMode
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        surfaceContainerLow:
            darkMode ? const Color(0xFF24304C) : const Color(0xFFF1F5F9),
        outlineVariant:
            darkMode ? const Color(0xFF42506B) : const Color(0xFFD8E1EC),
      ),
      scaffoldBackgroundColor:
          darkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
    );
    return showModalBottomSheet<BookChapterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: sheetTheme,
        child: BookChapterSelectorSheet(
          currentBookId: currentBookId,
          currentChapter: currentChapter,
          initialBooks: initialBooks,
        ),
      ),
    );
  }

  @override
  State<BookChapterSelectorSheet> createState() =>
      _BookChapterSelectorSheetState();
}

class _BookChapterSelectorSheetState extends State<BookChapterSelectorSheet> {
  late final Future<List<BibleBook>> _books = _loadBooks();
  int? _expandedBookId;

  Future<List<BibleBook>> _loadBooks() async {
    if (widget.initialBooks != null) return widget.initialBooks!;
    final db = await DatabaseService.database;
    final rows = await db.query('books', orderBy: 'position ASC, id ASC');
    return rows.map(BibleBook.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Material(
        key: const ValueKey('book-selector-surface'),
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 58,
              height: 5,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Livres',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: FutureBuilder<List<BibleBook>>(
                future: _books,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Impossible de charger les livres.'),
                    );
                  }
                  final books = snapshot.data ?? const [];
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return _BookRow(
                        book: book,
                        expanded: _expandedBookId == book.id,
                        currentBookId: widget.currentBookId,
                        currentChapter: widget.currentChapter,
                        onToggle: () => setState(() {
                          _expandedBookId =
                              _expandedBookId == book.id ? null : book.id;
                        }),
                        onChapterSelected: (chapter) => Navigator.pop(
                          context,
                          BookChapterSelection(book: book, chapter: chapter),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final BibleBook book;
  final bool expanded;
  final int currentBookId;
  final int currentChapter;
  final VoidCallback onToggle;
  final ValueChanged<int> onChapterSelected;

  const _BookRow({
    required this.book,
    required this.expanded,
    required this.currentBookId,
    required this.currentChapter,
    required this.onToggle,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCurrentBook = book.id == currentBookId;
    return Column(
      children: [
        ListTile(
          onTap: onToggle,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          tileColor: isCurrentBook
              ? colors.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            book.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isCurrentBook ? colors.primary : colors.onSurface,
                  fontWeight:
                      isCurrentBook ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          trailing: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isCurrentBook ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: book.chaptersCount,
                    itemBuilder: (context, index) {
                      final chapter = index + 1;
                      final selected =
                          isCurrentBook && chapter == currentChapter;
                      return InkWell(
                        onTap: () => onChapterSelected(chapter),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.primary
                                : colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? colors.primary
                                  : colors.outlineVariant,
                            ),
                          ),
                          child: Text(
                            '$chapter',
                            style: TextStyle(
                              color: selected
                                  ? colors.onPrimary
                                  : colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
