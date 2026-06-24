import 'dart:typed_data';

import 'package:contact_photos/extensions/byte_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Uint8ListExtensions.looksLikeImageBytes', () {
    test('returns false when fewer than 12 bytes', () {
      expect(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]).looksLikeImageBytes(),
          isFalse);
      expect(Uint8List(0).looksLikeImageBytes(), isFalse);
      expect(Uint8List(11).looksLikeImageBytes(), isFalse);
    });

    test('detects PNG magic bytes', () {
      final png = Uint8List(12)
        ..[0] = 0x89
        ..[1] = 0x50
        ..[2] = 0x4E
        ..[3] = 0x47;
      expect(png.looksLikeImageBytes(), isTrue);
    });

    test('detects JPEG magic bytes', () {
      final jpeg = Uint8List(12)
        ..[0] = 0xFF
        ..[1] = 0xD8;
      expect(jpeg.looksLikeImageBytes(), isTrue);
    });

    test('detects GIF magic bytes', () {
      final gif = Uint8List(12)
        ..[0] = 0x47
        ..[1] = 0x49
        ..[2] = 0x46
        ..[3] = 0x38;
      expect(gif.looksLikeImageBytes(), isTrue);
    });

    test('detects WebP magic bytes', () {
      final webp = Uint8List(12)
        ..[0] = 0x52  // R
        ..[1] = 0x49  // I
        ..[2] = 0x46  // F
        ..[3] = 0x46  // F
        ..[8] = 0x57  // W
        ..[9] = 0x45  // E
        ..[10] = 0x42 // B
        ..[11] = 0x50; // P
      expect(webp.looksLikeImageBytes(), isTrue);
    });

    test('detects ICO magic bytes', () {
      final ico = Uint8List(12)
        ..[0] = 0x00
        ..[1] = 0x00
        ..[2] = 0x01
        ..[3] = 0x00;
      expect(ico.looksLikeImageBytes(), isTrue);
    });

    test('returns false for random bytes', () {
      final random = Uint8List(12)
        ..[0] = 0xAB
        ..[1] = 0xCD;
      expect(random.looksLikeImageBytes(), isFalse);
    });

    test('returns false for all-zero bytes (12+)', () {
      expect(Uint8List(12).looksLikeImageBytes(), isFalse);
    });
  });
}
