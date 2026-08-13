import 'package:flutter/material.dart';
import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/home/widgets/resume_reading_card.dart';
import 'package:echo_bible/features/home/widgets/today_reading_plan_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Map<String, String> _getDynamicGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return {
        "title": "Bonjour,",
        "message": "Que la grâce de Dieu vous accompagne aujourd'hui."
      };
    } else if (hour >= 11 && hour < 17) {
      return {
        "title": "Bon après-midi,",
        "message": "Que le Seigneur fortifie chacun de vos pas."
      };
    } else if (hour >= 17 && hour < 22) {
      return {
        "title": "Bonsoir,",
        "message": "Que la paix du Christ repose sur vous."
      };
    } else {
      return {
        "title": "Bonne nuit,",
        "message": "Que Dieu veille sur votre sommeil et renouvelle vos forces."
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getDynamicGreeting();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // --- EN-TÊTE BLEU ---
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne Salutation dynamique + Cloche
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting["title"]!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              greeting["message"]!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none,
                              color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- WIDGET REPRENDRE LA LECTURE ---
                  ResumeReadingCard(
                    onResume: (bookId, chapter, bookName) async {
                      final database = await DatabaseService.database;
                      final books = await database.query(
                        'books',
                        where: 'id = ?',
                        whereArgs: [bookId],
                        limit: 1,
                      );
                      if (!context.mounted || books.isEmpty) return;
                      final book = BibleBook.fromMap(books.first);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChapterReaderScreen(
                            book: book,
                            initialChapter: chapter,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  const TodayReadingPlanCard(),
                ],
              ),
            ),

            // --- CORPS DE LA PAGE ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section "100% Gratuit"
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite,
                              size: 16, color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Application 100% gratuite",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Soutenez-nous par un don pour faire grandir le projet.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            "Soutenir",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
