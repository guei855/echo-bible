import 'dart:io';

import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/plans/models/reading_reminder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef ReminderDatabaseProvider = Future<Database> Function();

abstract interface class ReadingReminderScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> schedule(
    ReadingReminder reminder, {
    required String planTitle,
    String? todayReading,
  });
  Future<void> cancel(int notificationId);
}

class ReadingReminderRepository {
  ReadingReminderRepository({
    ReminderDatabaseProvider? databaseProvider,
    ReadingReminderScheduler? scheduler,
    DateTime Function()? clock,
  })  : _databaseProvider =
            databaseProvider ?? (() => DatabaseService.database),
        _scheduler = scheduler ?? LocalReadingReminderScheduler(),
        _clock = clock ?? DateTime.now;

  final ReminderDatabaseProvider _databaseProvider;
  final ReadingReminderScheduler _scheduler;
  final DateTime Function() _clock;

  static int notificationId(int planId, int reminderId) {
    var hash = 17;
    hash = (hash * 37 + planId) & 0x3fffffff;
    hash = (hash * 37 + reminderId) & 0x3fffffff;
    return 100000 + hash;
  }

  Future<ReadingReminderPlanSettings> load(int planId) async {
    final db = await _databaseProvider();
    final state = await db.query(
      'reading_plan_reminder_settings',
      columns: const ['enabled'],
      where: 'plan_id = ?',
      whereArgs: [planId],
      limit: 1,
    );
    final rows = await db.query(
      'reading_plan_reminders',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'hour, minute, id',
    );
    return ReadingReminderPlanSettings(
      planId: planId,
      enabled: state.isNotEmpty && (state.first['enabled'] as int? ?? 0) == 1,
      reminders: rows.map(_fromRow).toList(growable: false),
    );
  }

  Future<ReadingReminder> add({
    required int planId,
    required int hour,
    required int minute,
    required String planTitle,
    String? todayReading,
  }) async {
    _validateTime(hour, minute);
    final db = await _databaseProvider();
    final settings = await load(planId);
    if (settings.reminders.any(
      (item) => item.hour == hour && item.minute == minute,
    )) {
      throw StateError('Ce rappel existe déjà.');
    }
    final id = await db.insert('reading_plan_reminders', {
      'plan_id': planId,
      'hour': hour,
      'minute': minute,
      'enabled': 1,
      'created_at': _clock().toIso8601String(),
    });
    final reminder = ReadingReminder(
      id: id,
      planId: planId,
      hour: hour,
      minute: minute,
      enabled: true,
      createdAt: _clock(),
    );
    if (settings.enabled) {
      await _scheduler.schedule(
        reminder,
        planTitle: planTitle,
        todayReading: todayReading,
      );
    }
    return reminder;
  }

  Future<ReadingReminder> update(
    ReadingReminder reminder, {
    required int hour,
    required int minute,
    required String planTitle,
    String? todayReading,
  }) async {
    _validateTime(hour, minute);
    final db = await _databaseProvider();
    final duplicate = await db.query(
      'reading_plan_reminders',
      columns: const ['id'],
      where: 'plan_id = ? AND hour = ? AND minute = ? AND id <> ?',
      whereArgs: [reminder.planId, hour, minute, reminder.id],
      limit: 1,
    );
    if (duplicate.isNotEmpty) throw StateError('Ce rappel existe déjà.');
    await db.update(
      'reading_plan_reminders',
      {'hour': hour, 'minute': minute},
      where: 'id = ? AND plan_id = ?',
      whereArgs: [reminder.id, reminder.planId],
    );
    await _scheduler.cancel(notificationId(reminder.planId, reminder.id));
    final updated = reminder.copyWith(hour: hour, minute: minute);
    final plan = await load(reminder.planId);
    if (plan.enabled && updated.enabled) {
      await _scheduler.schedule(
        updated,
        planTitle: planTitle,
        todayReading: todayReading,
      );
    }
    return updated;
  }

  Future<void> remove(ReadingReminder reminder) async {
    final db = await _databaseProvider();
    await db.delete(
      'reading_plan_reminders',
      where: 'id = ? AND plan_id = ?',
      whereArgs: [reminder.id, reminder.planId],
    );
    await _scheduler.cancel(notificationId(reminder.planId, reminder.id));
  }

  Future<void> removePlan(int planId) async {
    final settings = await load(planId);
    final db = await _databaseProvider();
    await db.transaction((transaction) async {
      await transaction.delete(
        'reading_plan_reminders',
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
      await transaction.delete(
        'reading_plan_reminder_settings',
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
    });
    for (final reminder in settings.reminders) {
      await _scheduler.cancel(notificationId(planId, reminder.id));
    }
  }

  Future<void> setReminderEnabled(
    ReadingReminder reminder,
    bool enabled, {
    required String planTitle,
    String? todayReading,
  }) async {
    final db = await _databaseProvider();
    await db.update(
      'reading_plan_reminders',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ? AND plan_id = ?',
      whereArgs: [reminder.id, reminder.planId],
    );
    if (!enabled) {
      await _scheduler.cancel(notificationId(reminder.planId, reminder.id));
      return;
    }
    final plan = await load(reminder.planId);
    if (plan.enabled) {
      await _scheduler.schedule(
        reminder.copyWith(enabled: true),
        planTitle: planTitle,
        todayReading: todayReading,
      );
    }
  }

  Future<bool> setPlanEnabled(
    int planId,
    bool enabled, {
    required String planTitle,
    String? todayReading,
  }) async {
    if (enabled && !await _scheduler.requestPermission()) return false;
    final db = await _databaseProvider();
    await db.insert(
      'reading_plan_reminder_settings',
      {'plan_id': planId, 'enabled': enabled ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final settings = await load(planId);
    for (final reminder in settings.reminders) {
      if (!enabled || !reminder.enabled) {
        await _scheduler.cancel(notificationId(planId, reminder.id));
      } else {
        await _scheduler.schedule(
          reminder,
          planTitle: planTitle,
          todayReading: todayReading,
        );
      }
    }
    return true;
  }

  Future<void> restoreAll() async {
    await _scheduler.initialize();
    final db = await _databaseProvider();
    final rows = await db.rawQuery('''
      SELECT r.*
      FROM reading_plan_reminders r
      JOIN reading_plan_reminder_settings s ON s.plan_id = r.plan_id
      WHERE r.enabled = 1 AND s.enabled = 1
      ORDER BY r.id
    ''');
    for (final row in rows) {
      final reminder = _fromRow(row);
      await _scheduler.schedule(
        reminder,
        planTitle: reminder.planId == 0 ? 'La Bible en 1 an' : 'Plan personnel',
      );
    }
  }

  ReadingReminder _fromRow(Map<String, Object?> row) => ReadingReminder(
        id: row['id'] as int,
        planId: row['plan_id'] as int,
        hour: row['hour'] as int,
        minute: row['minute'] as int,
        enabled: (row['enabled'] as int? ?? 1) == 1,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  static void _validateTime(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw RangeError('Heure de rappel invalide.');
    }
  }
}

class ReadingReminderService {
  const ReadingReminderService._();

  static final ReadingReminderRepository repository =
      ReadingReminderRepository();

  static Future<void> initialize() async {
    await _migrateLegacyReminder();
    await repository.restoreAll();
  }

  static Future<void> _migrateLegacyReminder() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('reading_reminder_migrated_v2') == true) return;
    final enabled = preferences.getBool('reading_reminder_enabled') ?? false;
    final hadLegacyTime = preferences.containsKey('reading_reminder_hour') ||
        preferences.containsKey('reading_reminder_minute');
    final hour = preferences.getInt('reading_reminder_hour') ?? 7;
    final minute = preferences.getInt('reading_reminder_minute') ?? 0;
    final current = await repository.load(0);
    if ((enabled || hadLegacyTime) && current.reminders.isEmpty) {
      await repository.add(
        planId: 0,
        hour: hour,
        minute: minute,
        planTitle: 'La Bible en 1 an',
      );
      if (enabled) {
        await repository.setPlanEnabled(
          0,
          true,
          planTitle: 'La Bible en 1 an',
        );
      }
    }
    await preferences.setBool('reading_reminder_migrated_v2', true);
  }
}

class LocalReadingReminderScheduler implements ReadingReminderScheduler {
  static const _channelId = 'daily_reading_plan';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    tz_data.initializeTimeZones();
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '+' : '-';
    final hours = offset.inHours.abs();
    final minutes = offset.inMinutes.abs() % 60;
    final locationName = minutes == 0 ? 'Etc/GMT$sign$hours' : 'UTC';
    try {
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!_isSupported) return true;
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          true;
    }
    return true;
  }

  @override
  Future<void> schedule(
    ReadingReminder reminder, {
    required String planTitle,
    String? todayReading,
  }) async {
    await initialize();
    if (!_isSupported) return;
    var scheduled = tz.TZDateTime(
      tz.local,
      tz.TZDateTime.now(tz.local).year,
      tz.TZDateTime.now(tz.local).month,
      tz.TZDateTime.now(tz.local).day,
      reminder.hour,
      reminder.minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final id = ReadingReminderRepository.notificationId(
      reminder.planId,
      reminder.id,
    );
    await _notifications.cancel(id);
    await _notifications.zonedSchedule(
      id,
      'ECHO BIBLE — Rappel de lecture',
      todayReading?.trim().isNotEmpty == true
          ? todayReading
          : 'C’est l’heure de poursuivre votre plan « $planTitle ».',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Rappels des plans de lecture',
          channelDescription: 'Rappels quotidiens des plans bibliques',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'reading_plan:${reminder.planId}:${reminder.id}',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    if (_isSupported) await _notifications.cancel(notificationId);
  }

  static bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
