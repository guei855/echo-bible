import 'dart:async';

import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/plans/models/reading_plan.dart';
import 'package:echo_bible/features/plans/screens/reading_plans_screen.dart';
import 'package:echo_bible/features/plans/services/reading_plan_service.dart';
import 'package:flutter/material.dart';

class TodayReadingPlanCard extends StatefulWidget {
  const TodayReadingPlanCard({super.key});

  @override
  State<TodayReadingPlanCard> createState() => _TodayReadingPlanCardState();
}

class _TodayReadingPlanCardState extends State<TodayReadingPlanCard> {
  late Future<TodayReadingPlan> _today = ReadingPlanService.today();
  Timer? _calendarTimer;

  @override
  void initState() {
    super.initState();
    _scheduleCalendarRefresh();
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
    super.dispose();
  }

  void _scheduleCalendarRefresh() {
    _calendarTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _calendarTimer = Timer(tomorrow.difference(now), () async {
      final data = await ReadingPlanService.today();
      if (!mounted) return;
      final today = Future.value(data);
      setState(() {
        _today = today;
      });
      _scheduleCalendarRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TodayReadingPlan>(
      future: _today,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingPlanCard();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final plan = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Lecture du jour',
                      style: TextStyle(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openPlans,
                    child: const Text('Mes plans'),
                  ),
                ],
              ),
              Text(
                _longDate(plan.date),
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${plan.title} · Jour ${plan.day}/${plan.duration}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (plan.readings.isEmpty)
                const Text(
                  'Aucun passage prévu aujourd’hui.',
                  style: TextStyle(color: AppColors.textSecondaryLight),
                )
              else
                for (final reading in plan.readings)
                  _ReadingRow(
                    reading: reading,
                    onTap: () => _openReading(reading),
                  ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: plan.progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
                backgroundColor: const Color(0xFFE2E8F0),
                color: AppColors.secondary,
              ),
              if (plan.keyVerse != null) ...[
                const SizedBox(height: 16),
                _KeyVerseCard(
                  verse: plan.keyVerse!,
                  onTap: () => _openKeyVerse(plan.keyVerse!),
                ),
              ],
              const SizedBox(height: 14),
              _DailyTheme(theme: plan.theme),
            ],
          ),
        );
      },
    );
  }

  void _openReading(PlanReading reading) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: reading.bookId,
            name: reading.bookName,
            abbreviation: reading.abbreviation,
            testament: '',
            chaptersCount: reading.chaptersCount,
          ),
          initialChapter: reading.chapter,
        ),
      ),
    );
  }

  void _openKeyVerse(PlanKeyVerse verse) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: verse.bookId,
            name: verse.bookName,
            abbreviation: verse.abbreviation,
            testament: '',
            chaptersCount: verse.chaptersCount,
          ),
          initialChapter: verse.chapter,
        ),
      ),
    );
  }

  Future<void> _openPlans() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReadingPlansScreen()),
    );
    final data = await ReadingPlanService.today();
    if (!mounted) return;
    final today = Future.value(data);
    setState(() {
      _today = today;
    });
  }

  String _longDate(DateTime date) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${days[date.weekday - 1]} ${date.day} '
        '${months[date.month - 1]} ${date.year}';
  }
}

class _KeyVerseCard extends StatelessWidget {
  final PlanKeyVerse verse;
  final VoidCallback onTap;

  const _KeyVerseCard({required this.verse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Verset clé du jour',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white70,
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '« ${verse.text} »',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                verse.reference,
                style: const TextStyle(
                  color: Color(0xFFBFDBFE),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTheme extends StatelessWidget {
  final String theme;

  const _DailyTheme({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 19,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thème du jour',
                  style: TextStyle(
                    color: AppColors.textPrimaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  theme,
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  final PlanReading reading;
  final VoidCallback onTap;

  const _ReadingRow({required this.reading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${reading.bookName} ${reading.chapter}',
                style: const TextStyle(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${reading.estimatedMinutes} min',
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _LoadingPlanCard extends StatelessWidget {
  const _LoadingPlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const CircularProgressIndicator(),
    );
  }
}
