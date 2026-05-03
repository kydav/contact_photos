import 'package:contact_photos/services/hybrid_company_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('plain company text can return no local match without probe', () async {
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
  });
}
