import 'dart:typed_data';

import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _fakeBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

void main() {
  group('CompanyImageOption.isFromLogoKit', () {
    test('returns true for img.logokit.com host', () {
      final option = CompanyImageOption(
        url: 'https://img.logokit.com/example.com?token=abc',
        bytes: _fakeBytes,
      );
      expect(option.isFromLogoKit, isTrue);
    });

    test('returns true for logokit.com host', () {
      final option = CompanyImageOption(
        url: 'https://logokit.com/example.com',
        bytes: _fakeBytes,
      );
      expect(option.isFromLogoKit, isTrue);
    });

    test('returns true for www.logokit.com host', () {
      final option = CompanyImageOption(
        url: 'https://www.logokit.com/example.com',
        bytes: _fakeBytes,
      );
      expect(option.isFromLogoKit, isTrue);
    });

    test('returns false for non-logokit URL', () {
      final option = CompanyImageOption(
        url: 'https://example.com/logo.png',
        bytes: _fakeBytes,
      );
      expect(option.isFromLogoKit, isFalse);
    });

    test('returns false for URL that merely contains "logokit" in path', () {
      final option = CompanyImageOption(
        url: 'https://example.com/logokit/image.png',
        bytes: _fakeBytes,
      );
      expect(option.isFromLogoKit, isFalse);
    });

    test('returns false for malformed URL', () {
      final option = CompanyImageOption(
        url: 'not a url',
        bytes: _fakeBytes,
      );
      expect(option.isFromLogoKit, isFalse);
    });
  });
}
