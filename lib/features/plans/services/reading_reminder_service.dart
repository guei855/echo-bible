import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReadingReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const ReadingReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });
}

class ReadingReminderService {
  const ReadingReminderService._();

  static const _notificationId = 1401;
  static const _enabledKey = 'reading_reminder_enabled';
  static const _hourKey = 'reading_reminder_hour';
  static const _minuteKey = 'reading_reminder_minute';
  static const _channelId = 'daily_reading_plan';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
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
    final settings = await loadSettings();
    if (settings.enabled) {
      await _schedule(settings.hour, settings.minute, requestPermission: false);
    }
  }

  static Future<ReadingReminderSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    return ReadingReminderSettings(
      enabled: preferences.getBool(_enabledKey) ?? false,
      hour: preferences.getInt(_hourKey) ?? 7,
      minute: preferences.getInt(_minuteKey) ?? 0,
    );
  }

  static Future<bool> enable({required int hour, required int minute}) async {
    await initialize();
    if (!_isSupported) return false;
    final granted = await _requestPermission();
    if (!granted) return false;
    await _schedule(hour, minute, requestPermission: false);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, true);
    await preferences.setInt(_hourKey, hour);
    await preferences.setInt(_minuteKey, minute);
    return true;
  }

  static Future<void> disable() async {
    await initialize();
    await _notifications.cancel(_notificationId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
  }

  static Future<void> _schedule(
    int hour,
    int minute, {
    required bool requestPermission,
  }) async {
    var scheduled = tz.TZDateTime(
      tz.local,
      tz.TZDateTime.now(tz.local).year,
      tz.TZDateTime.now(tz.local).month,
      tz.TZDateTime.now(tz.local).day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _notifications.cancel(_notificationId);
    await _notifications.zonedSchedule(
      _notificationId,
      'Votre lecture ECHO BIBLE vous attend',
      'Découvrez les passages de votre plan actif pour aujourd’hui.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Rappel du plan de lecture',
          channelDescription:
              'Rappel quotidien pour la lecture biblique active',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'reading_plan',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<bool> _requestPermission() async {
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

  static bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
