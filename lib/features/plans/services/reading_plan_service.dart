import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/core/bible/bible_book_display_names.dart';
import 'package:echo_bible/features/plans/models/reading_plan.dart';
import 'package:echo_bible/features/plans/services/reading_reminder_service.dart';

class ReadingPlanService {
  const ReadingPlanService._();

  static const int defaultDuration = 365;
  static const String defaultTitle = 'La Bible en 1 an';

  static int calendarDay(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    var day =
        DateTime(date.year, date.month, date.day).difference(firstDay).inDays +
            1;
    final leapYear = DateTime(date.year, 3, 1)
            .difference(DateTime(date.year, 2, 28))
            .inDays ==
        2;
    if (leapYear && date.month > 2) day--;
    if (leapYear && date.month == 2 && date.day == 29) day--;
    return day.clamp(1, defaultDuration).toInt();
  }

  static Future<TodayReadingPlan> today({DateTime? date}) async {
    final currentDate = date ?? DateTime.now();
    final active = await activePersonalPlan();
    if (active != null) {
      final day = active.dayAt(currentDate);
      final readings = await _personalReadings(active.id, day);
      final insight = await _dailyInsight(readings);
      return TodayReadingPlan(
        planId: active.id,
        title: active.title,
        day: day,
        duration: active.duration,
        date: currentDate,
        isDefault: false,
        readings: readings,
        keyVerse: insight.keyVerse,
        theme: insight.theme,
      );
    }
    return defaultDay(calendarDay(currentDate), date: currentDate);
  }

  static Future<TodayReadingPlan> defaultDay(
    int day, {
    DateTime? date,
  }) async {
    final db = await DatabaseService.database;
    final totalRow =
        await db.rawQuery('SELECT COUNT(*) AS total FROM chapters');
    final total = totalRow.first['total'] as int? ?? 0;
    final safeDay = day.clamp(1, defaultDuration).toInt();
    final base = total ~/ defaultDuration;
    final extra = total % defaultDuration;
    final count = base + (safeDay <= extra ? 1 : 0);
    final offset = safeDay <= extra
        ? (safeDay - 1) * (base + 1)
        : extra * (base + 1) + (safeDay - extra - 1) * base;
    final rows = await db.rawQuery('''
      SELECT c.book_id, c.chapter_number, c.verses_count,
        b.name AS book_name, b.abbreviation, b.chapters_count
      FROM chapters c
      JOIN books b ON b.id = c.book_id
      ORDER BY b.position ASC, c.chapter_number ASC
      LIMIT ? OFFSET ?
    ''', [count, offset]);
    final readings = rows.map(_readingFromRow).toList();
    final insight = await _dailyInsight(readings);
    return TodayReadingPlan(
      planId: null,
      title: defaultTitle,
      day: safeDay,
      duration: defaultDuration,
      date: date ?? DateTime.now(),
      isDefault: true,
      readings: readings,
      keyVerse: insight.keyVerse,
      theme: insight.theme,
    );
  }

  static Future<PersonalReadingPlan?> activePersonalPlan() async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'reading_plans',
      where: 'is_personal = 1 AND is_active = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _personalFromRow(rows.first);
  }

  static Future<List<PersonalReadingPlan>> personalPlans() async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'reading_plans',
      where: 'is_personal = 1',
      orderBy: 'is_active DESC, id DESC',
    );
    return rows.map(_personalFromRow).toList();
  }

  static Future<int> createPersonalPlan({
    required String title,
    required DateTime startDate,
    required int duration,
    required List<int> bookIds,
  }) async {
    final db = await DatabaseService.database;
    final placeholders = List.filled(bookIds.length, '?').join(', ');
    final chapters = await db.rawQuery('''
      SELECT c.book_id, c.chapter_number
      FROM chapters c
      JOIN books b ON b.id = c.book_id
      WHERE c.book_id IN ($placeholders)
      ORDER BY b.position ASC, c.chapter_number ASC
    ''', bookIds);
    if (chapters.isEmpty) {
      throw StateError(
          'Sélectionnez au moins un livre contenant des chapitres.');
    }
    return db.transaction((transaction) async {
      await transaction.update('reading_plans', {'is_active': 0});
      final planId = await transaction.insert('reading_plans', {
        'title': title.trim(),
        'duration': duration,
        'description': 'Plan personnalisé',
        'start_date': _dateKey(startDate),
        'is_personal': 1,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      final batch = transaction.batch();
      for (var index = 0; index < chapters.length; index++) {
        final day = ((index * duration) ~/ chapters.length) + 1;
        batch.insert('reading_plan_items', {
          'plan_id': planId,
          'day': day,
          'book_id': chapters[index]['book_id'],
          'chapter': chapters[index]['chapter_number'],
        });
      }
      await batch.commit(noResult: true);
      return planId;
    });
  }

  static Future<void> activate(int? planId) async {
    final db = await DatabaseService.database;
    await db.transaction((transaction) async {
      await transaction.update('reading_plans', {'is_active': 0});
      if (planId != null) {
        await transaction.update(
          'reading_plans',
          {'is_active': 1},
          where: 'id = ?',
          whereArgs: [planId],
        );
      }
    });
  }

  static Future<void> deletePersonalPlan(int planId) async {
    final db = await DatabaseService.database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'reading_plan_items',
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
      await transaction.delete(
        'reading_plans',
        where: 'id = ?',
        whereArgs: [planId],
      );
    });
    await ReadingReminderService.repository.removePlan(planId);
  }

  static Future<List<PlanReading>> _personalReadings(
    int planId,
    int day,
  ) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT rpi.book_id, rpi.chapter AS chapter_number,
        b.name AS book_name, b.abbreviation, b.chapters_count,
        c.verses_count
      FROM reading_plan_items rpi
      JOIN books b ON b.id = rpi.book_id
      LEFT JOIN chapters c ON c.book_id = rpi.book_id
        AND c.chapter_number = rpi.chapter
      WHERE rpi.plan_id = ? AND rpi.day = ?
      ORDER BY b.position ASC, rpi.chapter ASC
    ''', [planId, day]);
    return rows.map(_readingFromRow).toList();
  }

  static PlanReading _readingFromRow(Map<String, Object?> row) {
    final verses = row['verses_count'] as int? ?? 25;
    return PlanReading(
      bookId: row['book_id'] as int,
      bookName: BibleBookDisplayNames.french(
        row['book_id'] as int,
        fallback: row['book_name'] as String?,
      ),
      abbreviation: row['abbreviation'] as String? ?? '',
      chaptersCount: row['chapters_count'] as int,
      chapter: row['chapter_number'] as int,
      estimatedMinutes: ((verses / 18).ceil()).clamp(2, 12).toInt(),
    );
  }

  static Future<_DailyInsight> _dailyInsight(
    List<PlanReading> readings,
  ) async {
    if (readings.isEmpty) {
      return const _DailyInsight(
        keyVerse: null,
        theme: 'Prendre un temps pour écouter la Parole de Dieu.',
      );
    }

    final db = await DatabaseService.database;
    final conditions = <String>[];
    final arguments = <Object?>[];
    for (final reading in readings) {
      conditions.add('(book_id = ? AND chapter_number = ?)');
      arguments
        ..add(reading.bookId)
        ..add(reading.chapter);
    }
    final verses = await db.rawQuery('''
      SELECT book_id, chapter_number, verse_number, text
      FROM verses
      WHERE ${conditions.join(' OR ')}
      ORDER BY book_id ASC, chapter_number ASC, verse_number ASC
    ''', arguments);
    if (verses.isEmpty) {
      return const _DailyInsight(
        keyVerse: null,
        theme: 'Découvrir et méditer la Parole de Dieu.',
      );
    }

    _ThemeProfile? selectedTheme;
    var selectedThemeScore = 0;
    for (final profile in _themeProfiles) {
      var score = 0;
      for (final row in verses) {
        score += _keywordScore(
          _normalize(row['text'] as String? ?? ''),
          profile.keywords,
        );
      }
      if (score > selectedThemeScore) {
        selectedTheme = profile;
        selectedThemeScore = score;
      }
    }

    Map<String, Object?>? selectedVerse;
    var selectedVerseScore = -1;
    final keywords = selectedTheme?.keywords ?? const <String>[];
    for (final row in verses) {
      final text = row['text'] as String? ?? '';
      final normalized = _normalize(text);
      var score = _keywordScore(normalized, keywords) * 20;
      if (text.length >= 35 && text.length <= 220) score += 3;
      if (normalized.contains('dieu') ||
          normalized.contains('seigneur') ||
          normalized.contains('eternel')) {
        score += 2;
      }
      if (score > selectedVerseScore) {
        selectedVerseScore = score;
        selectedVerse = row;
      }
    }

    final verseRow = selectedVerse ?? verses.first;
    final reading = readings.firstWhere(
      (item) => item.bookId == verseRow['book_id'],
      orElse: () => readings.first,
    );
    return _DailyInsight(
      keyVerse: PlanKeyVerse(
        bookId: reading.bookId,
        bookName: reading.bookName,
        abbreviation: reading.abbreviation,
        chaptersCount: reading.chaptersCount,
        chapter: verseRow['chapter_number'] as int,
        verse: verseRow['verse_number'] as int,
        text: verseRow['text'] as String? ?? '',
      ),
      theme: selectedTheme?.summary ??
          'Dieu se révèle et conduit son peuple par sa Parole.',
    );
  }

  static int _keywordScore(String text, List<String> keywords) {
    var score = 0;
    for (final keyword in keywords) {
      var start = 0;
      while ((start = text.indexOf(keyword, start)) >= 0) {
        score++;
        start += keyword.length;
      }
    }
    return score;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('œ', 'oe');

  static PersonalReadingPlan _personalFromRow(Map<String, Object?> row) {
    return PersonalReadingPlan(
      id: row['id'] as int,
      title: row['title'] as String? ?? 'Plan personnel',
      duration: row['duration'] as int? ?? 30,
      startDate: DateTime.tryParse(row['start_date'] as String? ?? '') ??
          DateTime.now(),
      isActive: (row['is_active'] as int? ?? 0) == 1,
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _DailyInsight {
  final PlanKeyVerse? keyVerse;
  final String theme;

  const _DailyInsight({required this.keyVerse, required this.theme});
}

class _ThemeProfile {
  final String summary;
  final List<String> keywords;

  const _ThemeProfile(this.summary, this.keywords);
}

const _themeProfiles = <_ThemeProfile>[
  _ThemeProfile(
    'Dieu crée, ordonne et donne la vie.',
    ['crea', 'creation', 'commencement', 'cieux', 'lumiere', 'image de dieu'],
  ),
  _ThemeProfile(
    'Dieu guide et prend soin de son peuple.',
    [
      'berger',
      'brebis',
      'troupeau',
      'conduit',
      'garde',
      'soin',
      'pourvoi',
      'manquer'
    ],
  ),
  _ThemeProfile(
    'Faire confiance à Dieu et marcher par la foi.',
    ['foi', 'croire', 'crut', 'confiance', 'fidele', 'assurance'],
  ),
  _ThemeProfile(
    'L’amour de Dieu transforme nos relations.',
    ['amour', 'aime', 'charite', 'compassion', 'misericorde', 'pardonne'],
  ),
  _ThemeProfile(
    'Dieu sauve, délivre et offre une vie nouvelle.',
    ['salut', 'sauve', 'delivre', 'redemption', 'vie eternelle', 'ressusc'],
  ),
  _ThemeProfile(
    'Chercher Dieu dans la prière et la louange.',
    ['priere', 'pria', 'invoqu', 'lou', 'adora', 'cantique'],
  ),
  _ThemeProfile(
    'La sagesse de Dieu éclaire nos choix.',
    [
      'sagesse',
      'sage',
      'intelligence',
      'instruction',
      'connaissance',
      'prudence'
    ],
  ),
  _ThemeProfile(
    'Vivre dans la justice, la vérité et la droiture.',
    ['justice', 'juste', 'verite', 'droit', 'equite', 'integrite'],
  ),
  _ThemeProfile(
    'Obéir à Dieu et demeurer fidèle à sa parole.',
    ['obei', 'commandement', 'loi', 'alliance', 'fidelite', 'sanctifi'],
  ),
  _ThemeProfile(
    'Garder l’espérance dans les promesses de Dieu.',
    ['esper', 'promesse', 'attend', 'consol', 'courage', 'heritage'],
  ),
];
