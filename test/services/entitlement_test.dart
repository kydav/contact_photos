import 'package:contact_photos/services/preferences_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entitlement logic', () {
    setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('allows creation when count is below free limit', () async {
      final count = await PreferencesService.getContactsCreated();
      final unlocked = await PreferencesService.isPurchaseUnlocked();
      expect(count < 3 || unlocked, isTrue);
    });

    test('blocks creation when count equals free limit and not unlocked',
        () async {
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();
      await PreferencesService.incrementContactsCreated();

      final count = await PreferencesService.getContactsCreated();
      final unlocked = await PreferencesService.isPurchaseUnlocked();

      expect(count >= 3, isTrue);
      expect(unlocked, isFalse);
    });

    test('allows creation when unlocked regardless of count', () async {
      for (var i = 0; i < 5; i++) {
        await PreferencesService.incrementContactsCreated();
      }
      await PreferencesService.setPurchaseUnlocked();

      final count = await PreferencesService.getContactsCreated();
      final unlocked = await PreferencesService.isPurchaseUnlocked();

      expect(count, equals(5));
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
