import 'package:echo_bible/features/plans/services/reading_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('synchronise le jour du plan avec le calendrier annuel', () {
    expect(ReadingPlanService.calendarDay(DateTime(2026, 1, 1)), 1);
    expect(ReadingPlanService.calendarDay(DateTime(2026, 12, 31)), 365);
    expect(ReadingPlanService.calendarDay(DateTime(2028, 2, 28)), 59);
    expect(ReadingPlanService.calendarDay(DateTime(2028, 2, 29)), 59);
    expect(ReadingPlanService.calendarDay(DateTime(2028, 3, 1)), 60);
    expect(ReadingPlanService.calendarDay(DateTime(2028, 12, 31)), 365);
  });

  test('répartit les 1189 chapitres sur les 365 jours', () async {
    final first = await ReadingPlanService.defaultDay(
      1,
      date: DateTime(2026, 1, 1),
    );
    final last = await ReadingPlanService.defaultDay(
      365,
      date: DateTime(2026, 12, 31),
    );

    expect(first.title, ReadingPlanService.defaultTitle);
    expect(first.readings, hasLength(4));
    expect(first.readings.first.bookName, 'Genèse');
    expect(first.readings.first.chapter, 1);
    expect(first.keyVerse, isNotNull);
    expect(first.keyVerse!.bookName, 'Genèse');
    expect(first.keyVerse!.chapter, 1);
    expect(first.keyVerse!.text, isNotEmpty);
    expect(first.theme, 'Dieu crée, ordonne et donne la vie.');
    expect(last.readings.last.bookName, 'Apocalypse');
    expect(last.readings.last.chapter, 22);
  });
}
