import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSettingsService {
  const LanguageSettingsService._();
  static const _key = 'app_language';

  static Future<AppLanguage> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return AppLanguage.values
            .where((language) => language.name == value)
            .firstOrNull ??
        AppLanguage.fr;
  }

  static Future<void> save(AppLanguage language) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, language.name);
  }
}
