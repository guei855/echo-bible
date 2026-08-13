import 'package:echo_bible/features/bible/services/highlight_palette_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('conserve les couleurs personnalisées et résout leur teinte', () async {
    final promise = HighlightPaletteService.create(0xFF7E57C2);
    await HighlightPaletteService.saveCustomColors([promise]);

    final colors = await HighlightPaletteService.loadCustomColors();

    expect(colors, hasLength(1));
    expect(colors.single.name, isEmpty);
    expect(colors.single.key, 'custom_ff7e57c2');
    expect(
      HighlightPaletteService.resolveColor(colors.single.key)?.toARGB32(),
      0xFF7E57C2,
    );
    expect(
      HighlightPaletteService.resolveColor('orange')?.toARGB32(),
      0xFFFF9800,
    );
  });
}
