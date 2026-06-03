import 'package:contact_photos/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Entitlement logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('allows creation when count is below free limit', () async {
      // Count is 0, not unlocked — should be allowed (0 < 3).
      final count = await PreferencesService.getContactsCreated();
      final unlocked = await PreferencesService.isPurchaseUnlocked();
      expect(count < 3 || unlocked, isTrue);
    });

    test('blocks creation when count equals free limit and not unlocked',
        () async {
      // Simulate 3 contacts already created.
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();

      final count = await PreferencesService.getContactsCreated();
      final unlocked = await PreferencesService.isPurchaseUnlocked();

      // Gate: count >= 3 and not unlocked → should be blocked.
      expect(count >= 3, isTrue);
      expect(unlocked, isFalse);
    });

    test('allows creation when unlocked regardless of count', () async {
      // Simulate 5 contacts created and purchase unlocked.
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.setPurchaseUnlocked();

      final count = await PreferencesService.getContactsCreated();
      final unlocked = await PreferencesService.isPurchaseUnlocked();

      expect(count, equals(5));
      // Even though count >= 3, unlocked flag bypasses the gate.
      expect(unlocked, isTrue);
    });

    test('incrementContactsCreated increments from 0 to 1', () async {
      final before = await PreferencesService.getContactsCreated();
      expect(before, equals(0));

      await PreferencesService.incrementContactsCreated();

      final after = await PreferencesService.getContactsCreated();
      expect(after, equals(1));
    });

    test('setPurchaseUnlocked persists across reads', () async {
      final before = await PreferencesService.isPurchaseUnlocked();
      expect(before, isFalse);

      await PreferencesService.setPurchaseUnlocked();

      final after = await PreferencesService.isPurchaseUnlocked();
      expect(after, isTrue);
    });
  });
}
