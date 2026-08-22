import 'package:echo_bible/core/bible/bible_book_display_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retourne les noms canoniques français courts', () {
    expect(BibleBookDisplayNames.french(1), 'Genèse');
    expect(BibleBookDisplayNames.french(9), '1 Samuel');
    expect(BibleBookDisplayNames.french(10), '2 Samuel');
    expect(BibleBookDisplayNames.french(11), '1 Rois');
    expect(BibleBookDisplayNames.french(12), '2 Rois');
    expect(BibleBookDisplayNames.french(40), 'Matthieu');
    expect(BibleBookDisplayNames.french(43), 'Jean');
    expect(BibleBookDisplayNames.french(46), '1 Corinthiens');
    expect(BibleBookDisplayNames.french(47), '2 Corinthiens');
    expect(BibleBookDisplayNames.french(52), '1 Thessaloniciens');
    expect(BibleBookDisplayNames.french(54), '1 Timothée');
    expect(BibleBookDisplayNames.french(62), '1 Jean');
    expect(BibleBookDisplayNames.french(66), 'Apocalypse');
  });

  test('formate les références sans employer le nom source long', () {
    expect(
      BibleBookDisplayNames.reference(46, 2, verse: 2),
      '1 Corinthiens 2:2',
    );
    expect(BibleBookDisplayNames.reference(10, 1, verse: 1), '2 Samuel 1:1');
    expect(BibleBookDisplayNames.reference(40, 5, verse: 13), 'Matthieu 5:13');
    expect(BibleBookDisplayNames.reference(43, 3, verse: 16), 'Jean 3:16');
  });
}
