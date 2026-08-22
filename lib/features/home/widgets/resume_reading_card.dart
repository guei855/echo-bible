import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import '../../../core/bible/bible_book_display_names.dart';

class ResumeReadingCard extends StatefulWidget {
  final Function(int bookId, int chapter, String bookName) onResume;

  const ResumeReadingCard({super.key, required this.onResume});

  @override
  State<ResumeReadingCard> createState() => _ResumeReadingCardState();
}

class _ResumeReadingCardState extends State<ResumeReadingCard> {
  Map<String, dynamic>? _lastPosition;
  String _bookName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLastPosition();
  }

  Future<void> _loadLastPosition() async {
    try {
      final position = await DatabaseService.getLastReadingPosition();
      if (position != null) {
        final int bookId = position['book_id'];

        // Récupérer le nom du livre correspondant dans la table books
        final db = await DatabaseService.database;
        final bookResult = await db.query(
          'books',
          where: 'id = ?',
          whereArgs: [bookId],
          limit: 1,
        );

        if (bookResult.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _lastPosition = position;
            _bookName = BibleBookDisplayNames.french(
              bookId,
              fallback: bookResult.first['name'] as String?,
            );
            _isLoading = false;
          });
          return;
        }
      }
    } on Object {
      // Une carte secondaire ne doit jamais bloquer l'accueil si la base est
      // temporairement indisponible pendant une migration ou une restauration.
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // Si aucune lecture n'a encore été enregistrée, on ne s'affiche pas
    if (_lastPosition == null) {
      return const SizedBox.shrink();
    }

    final int bookId = _lastPosition!['book_id'];
    final int chapter = _lastPosition!['chapter'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onResume(bookId, chapter, _bookName),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const ContainerIconBackground(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reprendre la lecture',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_bookName - Chapitre $chapter',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContainerIconBackground extends StatelessWidget {
  const ContainerIconBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
