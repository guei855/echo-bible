import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_bible/features/bible/models/reader_theme.dart';

class SettingsService {
  static const String _keyFontSize = 'font_size';
  static const String _keyFontFamily = 'font_family';
  static const String _keyIsDarkMode = 'is_dark_mode';
  static const String _keyReaderTheme = 'reader_theme';
  static const String _keyLineHeight = 'line_height';

  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFontSize) ?? 18.0;
  }

  static Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
  }

  static Future<String> getFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFontFamily) ?? 'Roboto';
  }

  static Future<void> setFontFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, family);
  }

  static Future<double> getLineHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLineHeight) ?? 1.7;
  }

  static Future<void> setLineHeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineHeight, value);
  }

  static Future<ReaderThemeId> getReaderTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyReaderTheme);
    if (saved != null) {
      for (final theme in ReaderThemeId.values) {
        if (theme.name == saved) return theme;
      }
    }
    return (prefs.getBool(_keyIsDarkMode) ?? false)
        ? ReaderThemeId.dark
        : ReaderThemeId.light;
  }

  static Future<void> setReaderTheme(ReaderThemeId theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReaderTheme, theme.name);
    await prefs.setBool(_keyIsDarkMode, readerPaletteFor(theme).isDark);
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsDarkMode) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, value);
  }
}
