import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _introShownKey = 'intro_shown';
  static const _contactsCreatedKey = 'contacts_created_count';
  static const _purchaseUnlockedKey = 'purchase_unlocked';

  static Future<bool> hasShownIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introShownKey) ?? false;
  }

  static Future<void> setIntroShown({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introShownKey, value);
  }

  static Future<int> getContactsCreated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_contactsCreatedKey) ?? 0;
  }

  static Future<void> incrementContactsCreated() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_contactsCreatedKey) ?? 0;
    await prefs.setInt(_contactsCreatedKey, current + 1);
  }

  static Future<bool> isPurchaseUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_purchaseUnlockedKey) ?? false;
  }

  static Future<void> setPurchaseUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_purchaseUnlockedKey, true);
  }
}
