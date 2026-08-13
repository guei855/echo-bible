import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  test('résout les références OpenBible dans la Bible française', () async {
    const repository = CrossReferenceRepository();
    for (final reference in const [
      (1, 1, 1),
      (43, 3, 16),
      (45, 8, 28),
    ]) {
      final results = await repository.forVerse(
        reference.$1,
        reference.$2,
        reference.$3,
      );
      expect(results, isNotEmpty, reason: 'Référence source $reference');
      expect(
        results.every((result) => result.text.trim().isNotEmpty),
        isTrue,
      );
    }
  });
}
