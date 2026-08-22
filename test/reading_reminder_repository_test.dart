import 'package:echo_bible/features/plans/models/reading_reminder.dart';
import 'package:echo_bible/features/plans/services/reading_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late _FakeScheduler scheduler;
  late ReadingReminderRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE reading_plan_reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        UNIQUE(plan_id, hour, minute)
      )
    ''');
    await db.execute('''
      CREATE TABLE reading_plan_reminder_settings(
        plan_id INTEGER PRIMARY KEY,
        enabled INTEGER NOT NULL DEFAULT 0
      )
    ''');
    scheduler = _FakeScheduler();
    repository = ReadingReminderRepository(
      databaseProvider: () async => db,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 22),
    );
  });

  tearDown(() => db.close());

  Future<ReadingReminder> add(int hour, int minute, {int planId = 4}) {
    return repository.add(
      planId: planId,
      hour: hour,
      minute: minute,
      planTitle: 'Mon plan',
    );
  }

  test('crée un rappel structuré', () async {
    final reminder = await add(6, 0);
    expect(reminder.timeKey, '06:00');
    expect((await repository.load(4)).reminders, hasLength(1));
  });

  test('crée plusieurs rappels triés dans une journée', () async {
    await add(19, 0);
    await add(6, 0);
    await add(12, 30);
    expect(
      (await repository.load(4)).reminders.map((item) => item.timeKey),
      ['06:00', '12:30', '19:00'],
    );
  });

  test('refuse un doublon exact dans le même plan', () async {
    await add(6, 0);
    await expectLater(add(6, 0), throwsA(isA<StateError>()));
  });

  test('autorise la même heure dans deux plans', () async {
    await add(6, 0, planId: 1);
    await add(6, 0, planId: 2);
    expect((await repository.load(1)).reminders, hasLength(1));
    expect((await repository.load(2)).reminders, hasLength(1));
  });

  test('modifie une heure et reprogramme uniquement ce rappel', () async {
    final reminder = await add(6, 0);
    await repository.setPlanEnabled(4, true, planTitle: 'Mon plan');
    final updated = await repository.update(
      reminder,
      hour: 7,
      minute: 15,
      planTitle: 'Mon plan',
    );
    expect(updated.timeKey, '07:15');
    expect(scheduler.scheduled.values.single.timeKey, '07:15');
  });

  test('supprime un rappel et annule uniquement sa notification', () async {
    final first = await add(6, 0);
    final second = await add(19, 0);
    await repository.setPlanEnabled(4, true, planTitle: 'Mon plan');
    await repository.remove(first);
    expect(scheduler.scheduled.values.single.id, second.id);
    expect((await repository.load(4)).reminders.single.id, second.id);
  });

  test('désactive puis réactive un rappel', () async {
    final reminder = await add(6, 0);
    await repository.setPlanEnabled(4, true, planTitle: 'Mon plan');
    await repository.setReminderEnabled(
      reminder,
      false,
      planTitle: 'Mon plan',
    );
    expect(scheduler.scheduled, isEmpty);
    await repository.setReminderEnabled(
      reminder.copyWith(enabled: false),
      true,
      planTitle: 'Mon plan',
    );
    expect(scheduler.scheduled, hasLength(1));
  });

  test('OFF suspend tout sans perdre les heures', () async {
    await add(6, 0);
    await add(19, 0);
    await repository.setPlanEnabled(4, true, planTitle: 'Mon plan');
    await repository.setPlanEnabled(4, false, planTitle: 'Mon plan');
    expect(scheduler.scheduled, isEmpty);
    expect((await repository.load(4)).reminders, hasLength(2));
  });

  test('ON réactive tous les rappels individuels actifs', () async {
    final first = await add(6, 0);
    await add(19, 0);
    await repository.setReminderEnabled(
      first,
      false,
      planTitle: 'Mon plan',
    );
    await repository.setPlanEnabled(4, true, planTitle: 'Mon plan');
    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.scheduled.values.single.timeKey, '19:00');
  });

  test('persiste les rappels dans SQLite', () async {
    await add(12, 30);
    final reopened = ReadingReminderRepository(
      databaseProvider: () async => db,
      scheduler: _FakeScheduler(),
    );
    expect((await reopened.load(4)).reminders.single.timeKey, '12:30');
  });

  test('restaure les notifications actives après relance', () async {
    await add(6, 0);
    await add(19, 0);
    await repository.setPlanEnabled(4, true, planTitle: 'Mon plan');
    scheduler.scheduled.clear();
    await repository.restoreAll();
    expect(scheduler.scheduled, hasLength(2));
  });

  test('produit des IDs stables et distincts par plan et rappel', () {
    final first = ReadingReminderRepository.notificationId(4, 10);
    expect(first, ReadingReminderRepository.notificationId(4, 10));
    expect(first, isNot(ReadingReminderRepository.notificationId(4, 11)));
    expect(first, isNot(ReadingReminderRepository.notificationId(5, 10)));
  });
}

class _FakeScheduler implements ReadingReminderScheduler {
  bool permission = true;
  final Map<int, ReadingReminder> scheduled = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> schedule(
    ReadingReminder reminder, {
    required String planTitle,
    String? todayReading,
  }) async {
    scheduled[ReadingReminderRepository.notificationId(
      reminder.planId,
      reminder.id,
    )] = reminder;
  }

  @override
  Future<void> cancel(int notificationId) async {
    scheduled.remove(notificationId);
  }
}
