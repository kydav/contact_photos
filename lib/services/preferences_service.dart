import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _introShownKey = 'intro_shown';

  static Future<bool> hasShownIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introShownKey) ?? false;
  }

  static Future<void> setIntroShown({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introShownKey, value);
  }
}
