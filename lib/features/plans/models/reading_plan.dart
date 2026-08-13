class PlanReading {
  final int bookId;
  final String bookName;
  final String abbreviation;
  final int chaptersCount;
  final int chapter;
  final int estimatedMinutes;

  const PlanReading({
    required this.bookId,
    required this.bookName,
    required this.abbreviation,
    required this.chaptersCount,
    required this.chapter,
    required this.estimatedMinutes,
  });
}

class PlanKeyVerse {
  final int bookId;
  final String bookName;
  final String abbreviation;
  final int chaptersCount;
  final int chapter;
  final int verse;
  final String text;

  const PlanKeyVerse({
    required this.bookId,
    required this.bookName,
    required this.abbreviation,
    required this.chaptersCount,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get reference => '$bookName $chapter:$verse';
}

class TodayReadingPlan {
  final int? planId;
  final String title;
  final int day;
  final int duration;
  final DateTime date;
  final bool isDefault;
  final List<PlanReading> readings;
  final PlanKeyVerse? keyVerse;
  final String theme;

  const TodayReadingPlan({
    required this.planId,
    required this.title,
    required this.day,
    required this.duration,
    required this.date,
    required this.isDefault,
    required this.readings,
    required this.keyVerse,
    required this.theme,
  });

  double get progress =>
      duration == 0 ? 0 : (day / duration).clamp(0.0, 1.0).toDouble();
}

class PersonalReadingPlan {
  final int id;
  final String title;
  final int duration;
  final DateTime startDate;
  final bool isActive;

  const PersonalReadingPlan({
    required this.id,
    required this.title,
    required this.duration,
    required this.startDate,
    required this.isActive,
  });

  int dayAt(DateTime date) {
    final current = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return (current.difference(start).inDays + 1).clamp(1, duration).toInt();
  }
}
