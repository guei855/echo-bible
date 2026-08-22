class ReadingReminder {
  const ReadingReminder({
    required this.id,
    required this.planId,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.createdAt,
  });

  final int id;
  final int planId;
  final int hour;
  final int minute;
  final bool enabled;
  final DateTime createdAt;

  String get timeKey =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReadingReminder copyWith({int? hour, int? minute, bool? enabled}) {
    return ReadingReminder(
      id: id,
      planId: planId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }
}

class ReadingReminderPlanSettings {
  const ReadingReminderPlanSettings({
    required this.planId,
    required this.enabled,
    required this.reminders,
  });

  final int planId;
  final bool enabled;
  final List<ReadingReminder> reminders;
}
