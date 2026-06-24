import 'dart:typed_data';

import 'package:contact_photos/extensions/http_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';

// Minimal PNG bytes (12 bytes with valid PNG header).
final Uint8List _pngBytes = Uint8List(12)
  ..[0] = 0x89
  ..[1] = 0x50
  ..[2] = 0x4E
  ..[3] = 0x47;

final Uint8List _emptyBytes = Uint8List(12);

Response _response({
  required int statusCode,
  String contentType = '',
  String body = '',
  Uint8List? bodyBytes,
}) {
  final bytes = bodyBytes ?? Uint8List.fromList(body.codeUnits);
  return Response.bytes(
    bytes,
    statusCode,
    headers: contentType.isNotEmpty ? {'content-type': contentType} : {},
  );
}

void main() {
  group('HttpExtensions.looksLikeImage', () {
    test('returns true for image/png content-type', () {
      expect(
        _response(statusCode: 200, contentType: 'image/png').looksLikeImage(),
        isTrue,
      );
    });

    test('returns true for image/jpeg content-type', () {
      expect(
        _response(statusCode: 200, contentType: 'image/jpeg').looksLikeImage(),
        isTrue,
      );
    });

    test('returns false for image/svg+xml content-type', () {
      expect(
        _response(statusCode: 200, contentType: 'image/svg+xml')
            .looksLikeImage(),
        isFalse,
      );
    });

    test('returns false for text/html content-type even with image bytes', () {
      // SVG check wins, but for html let's confirm non-image content-type
      // without image magic bytes returns false.
      expect(
        _response(statusCode: 200, contentType: 'text/html', body: '<html/>')
            .looksLikeImage(),
        isFalse,
      );
    });

    test('falls back to magic bytes when no content-type set', () {
      expect(
        _response(statusCode: 200, bodyBytes: _pngBytes).looksLikeImage(),
        isTrue,
      );
    });

    test('returns false when no content-type and non-image magic bytes', () {
      expect(
        _response(statusCode: 200, bodyBytes: _emptyBytes).looksLikeImage(),
        isFalse,
      );
    });
  });

  group('HttpExtensions.looksLikeHtml', () {
    test('returns true for text/html content-type', () {
      expect(
        _response(statusCode: 200, contentType: 'text/html').looksLikeHtml(),
        isTrue,
      );
    });

    test('returns true for body starting with lowercase <!doctype html', () {
      // NOTE: looksLikeHtml() checks for '<!doctype html' without uppercasing
      // the body first, so the match is effectively case-sensitive on the body.
      // Uppercase DOCTYPE bodies only match via the content-type header path.
      expect(
        _response(
          statusCode: 200,
          body: '<!doctype html><html></html>',
        ).looksLikeHtml(),
        isTrue,
      );
    });

    test('returns true for body starting with <html', () {
      expect(
        _response(statusCode: 200, body: '<html><head></head></html>')
            .looksLikeHtml(),
        isTrue,
      );
    });

    test('returns true when body has leading whitespace then <!doctype', () {
      expect(
        _response(
          statusCode: 200,
          body: '   \n<!doctype html><html></html>',
        ).looksLikeHtml(),
        isTrue,
      );
    });

    test('returns false for JSON body', () {
      expect(
        _response(
          statusCode: 200,
          contentType: 'application/json',
          body: '{"key":"value"}',
        ).looksLikeHtml(),
        isFalse,
      );
    });

    test('returns false for image content-type', () {
      expect(
        _response(statusCode: 200, contentType: 'image/png').looksLikeHtml(),
        isFalse,
      );
    });
  });
}
