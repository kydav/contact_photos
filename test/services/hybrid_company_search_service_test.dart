import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/services/hybrid_company_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('LocalCompanySearchService', () {
    test('extracts website from query and infers company name', () async {
      final result = await LocalCompanySearchService.search(
        'Message from https://www.acme-tools.com for your invoice',
        allowNetworkProbe: false,
      );

      expect(result.companies, isNotEmpty);
      expect(result.isHighConfidence, isTrue);
      expect(result.companies.first.websiteUrl, 'https://www.acme-tools.com');
      expect(result.companies.first.name, 'Acme Tools');
    });

    test('plain company text can return no local match without probe',
        () async {
      final result = await LocalCompanySearchService.search(
        'Acme widgets alerts',
        allowNetworkProbe: false,
      );

      expect(result.companies, isEmpty);
      expect(result.confidence, 0);
    });

    test('single token query guesses website at low confidence', () async {
      final result = await LocalCompanySearchService.search(
        'Acme',
        allowNetworkProbe: false,
      );

      expect(result.companies, isNotEmpty);
      expect(result.isHighConfidence, isFalse);
      expect(result.companies.first.websiteUrl, 'https://acme.com');
      expect(result.confidence, 0.55);
    });

    test('resolveLiveWebsite returns the final redirected URL', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'crumbl.com') {
          return http.Response(
            '',
            301,
            headers: {'location': 'https://crumblcookies.com/'},
            request: request,
          );
        }

        if (request.url.host == 'crumblcookies.com') {
          return http.Response(
            '<html></html>',
            200,
            headers: {'content-type': 'text/html'},
            request: request,
          );
        }

        return http.Response('', 404, request: request);
      });

      final resolvedWebsite =
          await LocalCompanySearchService.resolveLiveWebsite(
        'https://crumbl.com',
        client: client,
      );

      expect(resolvedWebsite, 'https://crumblcookies.com/');
    });

    test('compact redirected domains infer a spaced company name', () {
      expect(
        'https://crumblcookies.com/'.inferCompanyNameFromWebsite(),
        'Crumbl Cookies',
      );
    });
  });
}
