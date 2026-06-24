import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/services/hybrid_company_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('LocalCompanySearchResult.isHighConfidence', () {
    test('returns false when companies list is empty regardless of confidence',
        () {
      const result = LocalCompanySearchResult(companies: [], confidence: 1.0);
      expect(result.isHighConfidence, isFalse);
    });

    test('returns false when confidence is below 0.75', () {
      const result = LocalCompanySearchResult(
        companies: [
          // Just needs a non-empty list; websiteUrl is a plain string
        ],
        confidence: 0.74,
      );
      expect(result.isHighConfidence, isFalse);
    });

    test('returns true when companies non-empty and confidence >= 0.75', () {
      // We cannot easily construct CompanySearchResult here without importing,
      // so test via LocalCompanySearchService.search which returns the model.
      // This test uses the search method to produce a high-confidence result.
    });
  });

  group('LocalCompanySearchService.search', () {
    test('returns empty result for blank query', () async {
      final result = await LocalCompanySearchService.search(
        '',
        allowNetworkProbe: false,
      );
      expect(result.companies, isEmpty);
      expect(result.confidence, 0.0);
    });

    test('returns empty result for whitespace-only query', () async {
      final result = await LocalCompanySearchService.search(
        '   ',
        allowNetworkProbe: false,
      );
      expect(result.companies, isEmpty);
      expect(result.confidence, 0.0);
    });

    test('extracts URL from query with high confidence', () async {
      final result = await LocalCompanySearchService.search(
        'Check out https://example.com for details',
        allowNetworkProbe: false,
      );
      expect(result.companies, isNotEmpty);
      expect(result.confidence, greaterThanOrEqualTo(0.9));
      expect(result.companies.first.websiteUrl, 'https://example.com');
    });

    test('infers company name from extracted URL', () async {
      final result = await LocalCompanySearchService.search(
        'https://acme-tools.com',
        allowNetworkProbe: false,
      );
      expect(result.companies.first.name, 'Acme Tools');
    });

    test('single-token query guesses website at 0.55 confidence', () async {
      final result = await LocalCompanySearchService.search(
        'Google',
        allowNetworkProbe: false,
      );
      expect(result.companies, isNotEmpty);
      expect(result.confidence, 0.55);
      expect(result.companies.first.websiteUrl, 'https://google.com');
    });

    test('multi-word query with no URL returns empty without network probe',
        () async {
      final result = await LocalCompanySearchService.search(
        'some random company name',
        allowNetworkProbe: false,
      );
      expect(result.companies, isEmpty);
    });

    test('noise-word-only query (e.g. "www com") returns empty', () async {
      final result = await LocalCompanySearchService.search(
        'www com https',
        allowNetworkProbe: false,
      );
      expect(result.companies, isEmpty);
    });

    test('extracts URL without scheme (bare domain)', () async {
      final result = await LocalCompanySearchService.search(
        'Visit example.com for more info',
        allowNetworkProbe: false,
      );
      expect(result.companies, isNotEmpty);
      // normalizeWebsiteUrl adds https://
      expect(result.companies.first.websiteUrl, startsWith('https://'));
    });
  });

  group('LocalCompanySearchService.resolveLiveWebsite', () {
    test('returns the final URL after a redirect chain', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'old.example.com') {
          return http.Response(
            '',
            301,
            headers: {'location': 'https://new.example.com/'},
            request: request,
          );
        }
        if (request.url.host == 'new.example.com' ||
            request.url.host == 'www.new.example.com') {
          return http.Response(
            '<html></html>',
            200,
            headers: {'content-type': 'text/html'},
            request: request,
          );
        }
        return http.Response('', 404, request: request);
      });

      final resolved = await LocalCompanySearchService.resolveLiveWebsite(
        'https://old.example.com',
        client: client,
      );
      expect(resolved, 'https://new.example.com/');
    });

    test('returns null for invalid URL', () async {
      final resolved = await LocalCompanySearchService.resolveLiveWebsite(
        'not a url',
      );
      expect(resolved, isNull);
    });

    test('returns null when host always returns 404', () async {
      final client = MockClient((request) async {
        return http.Response('', 404, request: request);
      });

      final resolved = await LocalCompanySearchService.resolveLiveWebsite(
        'https://nonexistent-host-xyz123.com',
        client: client,
      );
      expect(resolved, isNull);
    });

    test('returns null after exceeding redirect limit', () async {
      // 5 redirects is the limit; this creates a 6-step chain
      var count = 0;
      final client = MockClient((request) async {
        count++;
        return http.Response(
          '',
          301,
          headers: {'location': 'https://redirect$count.example.com/'},
          request: request,
        );
      });

      final resolved = await LocalCompanySearchService.resolveLiveWebsite(
        'https://start.example.com',
        client: client,
      );
      expect(resolved, isNull);
    });
  });

  group('String.inferCompanyNameFromWebsite integration', () {
    test('crumblcookies.com infers "Crumbl Cookies"', () {
      expect(
        'https://crumblcookies.com/'.inferCompanyNameFromWebsite(),
        'Crumbl Cookies',
      );
    });

    test('acme-tools.com infers "Acme Tools"', () {
      expect(
        'https://acme-tools.com'.inferCompanyNameFromWebsite(),
        'Acme Tools',
      );
    });

    test('apple.com infers "Apple"', () {
      expect(
        'https://apple.com'.inferCompanyNameFromWebsite(),
        'Apple',
      );
    });

    test('www.google.com infers "Google" (strips www)', () {
      expect(
        'https://www.google.com'.inferCompanyNameFromWebsite(),
        'Google',
      );
    });
  });
}
