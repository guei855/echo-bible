import 'package:flutter/material.dart';
import 'package:echo_bible/features/bible/data/database/database_helper.dart';
import 'package:echo_bible/features/bible/services/verse_action_service.dart';

class VerseActionsSheet extends StatelessWidget {
  final int bookId;
  final String bookName;
  final int chapterNumber;
  final int verseNumber;
  final String verseText;

  const VerseActionsSheet({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapterNumber,
    required this.verseNumber,
    required this.verseText,
  });

  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final existing = await db.query(
        'favorites',
        where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
        whereArgs: [bookId, chapterNumber, verseNumber],
      );

      if (existing.isNotEmpty) {
        await db.delete(
          'favorites',
          where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
          whereArgs: [bookId, chapterNumber, verseNumber],
        );
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retiré des favoris ⭐')),
        );
      } else {
        await db.insert('favorites', {
          'book_id': bookId,
          'chapter_number': chapterNumber,
          'verse_number': verseNumber,
          'text': verseText,
        });
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajouté aux favoris avec succès ⭐')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la gestion du favori : $e')),
      );
    }
  }

  void _openNoteDialog(BuildContext context) {
    Navigator.pop(context);
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note - $bookName $chapterNumber:$verseNumber'),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Écrivez votre note personnelle ici...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = noteController.text.trim();
              if (content.isNotEmpty) {
                try {
                  final db = await DatabaseHelper.instance.database;

                  await db.insert('notes', {
                    'book_id': bookId,
                    'chapter_number': chapterNumber,
                    'verse_number': verseNumber,
                    'content': content,
                  });

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Note enregistrée dans SQLite 📝')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erreur lors de l\'enregistrement : $e')),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _openHighlightDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une couleur'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _colorButton(context, Colors.yellow, 'yellow', 'Jaune'),
            _colorButton(context, Colors.green, 'green', 'Vert'),
            _colorButton(context, Colors.pink, 'pink', 'Rose'),
            _colorButton(context, Colors.blue, 'blue', 'Bleu'),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(
      BuildContext context, Color color, String colorKey, String name) {
    return GestureDetector(
      onTap: () async {
        try {
          final db = await DatabaseHelper.instance.database;

          final existing = await db.query(
            'highlights',
            where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
            whereArgs: [bookId, chapterNumber, verseNumber],
          );

          if (existing.isNotEmpty) {
            await db.update(
              'highlights',
              {'color': colorKey},
              where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
              whereArgs: [bookId, chapterNumber, verseNumber],
            );
          } else {
            await db.insert('highlights', {
              'book_id': bookId,
              'chapter_number': chapterNumber,
              'verse_number': verseNumber,
              'color': colorKey,
            });
          }

          if (!context.mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verset surligné en $name 🖌️')),
          );
        } catch (e) {
          if (!context.mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      },
      child: CircleAvatar(backgroundColor: color, radius: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$bookName $chapterNumber:$verseNumber',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '« $verseText »',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionChip(
                icon: Icons.copy,
                label: 'Copier',
                onTap: () async {
                  await VerseActionService.copyVerse(
                      bookName, chapterNumber, verseNumber, verseText);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Verset copié dans le presse-papier')),
                  );
                },
              ),
              _ActionChip(
                icon: Icons.share,
                label: 'Partager',
                onTap: () async {
                  await VerseActionService.shareVerse(
                      bookName, chapterNumber, verseNumber, verseText);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Verset copié pour le partage')),
                  );
                },
              ),
              _ActionChip(
                icon: Icons.brush,
                label: 'Surligner',
                onTap: () => _openHighlightDialog(context),
              ),
              _ActionChip(
                icon: Icons.edit_note,
                label: 'Note',
                onTap: () => _openNoteDialog(context),
              ),
              _ActionChip(
                icon: Icons.favorite,
                label: 'Favoris',
                onTap: () => _toggleFavorite(context),
              ),
              _ActionChip(
                icon: Icons.compare_arrows,
                label: 'Comparer',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Fonctionnalité Comparaison à venir')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF1E3A8A)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
