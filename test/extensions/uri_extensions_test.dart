import 'package:contact_photos/extensions/uri_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UriExtensions.buildWebsiteCandidates', () {
    test('returns https root and www variant for non-www host', () {
      final uri = Uri.parse('https://example.com/');
      final candidates = uri.buildWebsiteCandidates();
      final strings = candidates.map((u) => u.toString()).toList();

      expect(strings, contains('https://example.com/'));
      expect(strings, contains('https://www.example.com/'));
    });

    test('returns https root and no-www variant for www host', () {
      final uri = Uri.parse('https://www.example.com/');
      final candidates = uri.buildWebsiteCandidates();
      final strings = candidates.map((u) => u.toString()).toList();

      expect(strings, contains('https://www.example.com/'));
      expect(strings, contains('https://example.com/'));
    });

    test('does not strip www when removal would leave a bare TLD', () {
      // e.g. "www.com" — stripping www would give "com" which has no dot
      final uri = Uri.parse('https://www.com/');
      final candidates = uri.buildWebsiteCandidates();
      final strings = candidates.map((u) => u.toString()).toList();

      // Should still include the original host
      expect(strings, contains('https://www.com/'));
      // Should NOT add 'https://com/' (no dot after stripping www)
      expect(strings, isNot(contains('https://com/')));
    });

    test('all candidates use https scheme', () {
      final uri = Uri.parse('https://example.com/');
      for (final candidate in uri.buildWebsiteCandidates()) {
        expect(candidate.scheme, 'https');
      }
    });

    test('returns distinct URLs (no duplicates)', () {
      final uri = Uri.parse('https://example.com/');
      final candidates = uri.buildWebsiteCandidates();
      final strings = candidates.map((u) => u.toString()).toList();
      expect(strings.toSet().length, strings.length);
    });
  });

  group('UriExtensions.buildCommonImageAssetUrls', () {
    test('includes favicon.ico path', () {
      final uri = Uri.parse('https://example.com/');
      final urls = uri.buildCommonImageAssetUrls();
      expect(urls, contains('https://example.com/favicon.ico'));
    });

    test('includes apple-touch-icon.png path', () {
      final uri = Uri.parse('https://example.com/');
      final urls = uri.buildCommonImageAssetUrls();
      expect(urls, contains('https://example.com/apple-touch-icon.png'));
    });

    test('includes Google favicon CDN URL', () {
      final uri = Uri.parse('https://example.com/');
      final urls = uri.buildCommonImageAssetUrls();
      expect(
        urls.any((u) => u.contains('google.com/s2/favicons')),
        isTrue,
      );
    });

    test('all URLs use https scheme', () {
      final uri = Uri.parse('https://example.com/');
      for (final url in uri.buildCommonImageAssetUrls()) {
        expect(url.startsWith('https://'), isTrue);
      }
    });

    test('returns distinct URLs (no duplicates)', () {
      final uri = Uri.parse('https://example.com/');
      final urls = uri.buildCommonImageAssetUrls();
      expect(urls.toSet().length, urls.length);
    });
  });
}
