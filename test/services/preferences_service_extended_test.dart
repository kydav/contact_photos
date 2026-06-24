import 'package:contact_photos/services/preferences_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreferencesService', () {
    setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    group('hasShownIntro', () {
      test('returns false when key has never been set', () async {
        expect(await PreferencesService.hasShownIntro(), isFalse);
      });

      test('returns true after setIntroShown(value: true)', () async {
        await PreferencesService.setIntroShown(value: true);
        expect(await PreferencesService.hasShownIntro(), isTrue);
      });

      test('returns false after setIntroShown(value: false)', () async {
        await PreferencesService.setIntroShown(value: true);
        await PreferencesService.setIntroShown(value: false);
        expect(await PreferencesService.hasShownIntro(), isFalse);
      });
    });

    group('getContactsCreated / incrementContactsCreated', () {
      test('starts at 0 with empty storage', () async {
        expect(await PreferencesService.getContactsCreated(), 0);
      });

      test('increments from 0 to 1', () async {
        await PreferencesService.incrementContactsCreated();
        expect(await PreferencesService.getContactsCreated(), 1);
      });

      test('increments multiple times correctly', () async {
        for (var i = 0; i < 5; i++) {
          await PreferencesService.incrementContactsCreated();
        }
        expect(await PreferencesService.getContactsCreated(), 5);
      });
    });

    group('isPurchaseUnlocked / setPurchaseUnlocked', () {
      test('returns false when never set', () async {
        expect(await PreferencesService.isPurchaseUnlocked(), isFalse);
      });

      test('returns true after setPurchaseUnlocked()', () async {
        await PreferencesService.setPurchaseUnlocked();
        expect(await PreferencesService.isPurchaseUnlocked(), isTrue);
      });

      test('unlocked state persists across multiple reads', () async {
        await PreferencesService.setPurchaseUnlocked();
        expect(await PreferencesService.isPurchaseUnlocked(), isTrue);
        expect(await PreferencesService.isPurchaseUnlocked(), isTrue);
      });
    });

    group('entitlement gate logic', () {
      test('contact count below 3 and not unlocked — should be allowed', () async {
        await PreferencesService.incrementContactsCreated();
        await PreferencesService.incrementContactsCreated();

        final count = await PreferencesService.getContactsCreated();
        final unlocked = await PreferencesService.isPurchaseUnlocked();
        expect(count < 3 || unlocked, isTrue);
      });

      test('contact count at 3 and not unlocked — should be gated', () async {
        await PreferencesService.incrementContactsCreated();
        await PreferencesService.incrementContactsCreated();
        await PreferencesService.incrementContactsCreated();

        final count = await PreferencesService.getContactsCreated();
        final unlocked = await PreferencesService.isPurchaseUnlocked();
        expect(count >= 3 && !unlocked, isTrue);
      });

      test('contact count >= 3 but unlocked — should be allowed', () async {
        for (var i = 0; i < 10; i++) {
          await PreferencesService.incrementContactsCreated();
        }
        await PreferencesService.setPurchaseUnlocked();

        final count = await PreferencesService.getContactsCreated();
        final unlocked = await PreferencesService.isPurchaseUnlocked();
        expect(count >= 3, isTrue);
        expect(unlocked, isTrue);
      });
    });
  });
}
