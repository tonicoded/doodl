import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  static const _kLanguage = 'app.language';

  static Future<String> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kLanguage) ?? 'en').trim().toLowerCase();
  }

  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, code.trim().toLowerCase());
  }
}
