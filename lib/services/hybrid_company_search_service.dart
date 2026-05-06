import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/extensions/uri_extensions.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/ai_service.dart';

class HybridCompanySearchService {
  static Future<List<CompanySearchResult>> searchCompanies(String query) async {
    final localResult = await LocalCompanySearchService.search(query);
    if (localResult.isHighConfidence) {
      return localResult.companies;
    }

    try {
      final aiResults = await AiService.queryCompaniesFromGemini(query);
      final merged = <CompanySearchResult>[];
      final seen = <String>{};
      for (final company in [...localResult.companies, ...aiResults]) {
        if (!seen.add(company.websiteUrl)) {
          continue;
        }
        merged.add(company);
        if (merged.length >= 6) {
          break;
        }
      }
      return merged;
    } catch (_) {
      if (localResult.companies.isNotEmpty) {
        return localResult.companies;
      }
      rethrow;
    }
  }
}

class LocalCompanySearchResult {
  const LocalCompanySearchResult({
    required this.companies,
    required this.confidence,
  });

  final List<CompanySearchResult> companies;
  final double confidence;

  bool get isHighConfidence => companies.isNotEmpty && confidence >= 0.75;
}

class LocalCompanySearchService {
  static Future<LocalCompanySearchResult> search(
    String query, {
    bool allowNetworkProbe = true,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const LocalCompanySearchResult(companies: [], confidence: 0);
    }

    final extractedWebsites = _extractWebsites(trimmedQuery);
    if (extractedWebsites.isNotEmpty) {
      return LocalCompanySearchResult(
        companies: extractedWebsites
            .map(
              (website) => CompanySearchResult(
                name: _companyNameFromWebsite(website),
                websiteUrl: website,
              ),
            )
            .toList(),
        confidence: 0.95,
      );
    }

    if (allowNetworkProbe) {
      final probedWebsites = await _probeCandidateWebsites(trimmedQuery);
      if (probedWebsites.isNotEmpty) {
        return LocalCompanySearchResult(
          companies: probedWebsites
              .map(
                (website) => CompanySearchResult(
                  name: _companyNameFromWebsite(website),
                  websiteUrl: website,
                ),
              )
              .toList(),
          confidence: 0.8,
        );
      }
    }

    final guessedWebsite = _guessWebsiteFromSingleToken(trimmedQuery);
    if (guessedWebsite == null) {
      return const LocalCompanySearchResult(companies: [], confidence: 0);
    }

    return LocalCompanySearchResult(
      companies: [
        CompanySearchResult(
          name: _companyNameFromWebsite(guessedWebsite),
          websiteUrl: guessedWebsite,
        ),
      ],
      confidence: 0.55,
    );
  }

  static List<String> _extractWebsites(String query) {
    final candidates = <String>{};
    final regex = RegExp(
      r'((?:https?:\/\/)?(?:www\.)?[a-zA-Z0-9-]+(?:\.[a-zA-Z]{2,})(?:\/[^\s]*)?)',
      caseSensitive: false,
    );
    for (final match in regex.allMatches(query)) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      final normalized =
          raw.trimTrailingUrlPunctuation(removeDot: true).normalizeWebsiteUrl();
      if (normalized == null) {
        continue;
      }
      candidates.add(normalized);
    }
    return candidates.toList();
  }

  static String? _guessWebsiteFromSingleToken(String query) {
    if (query.contains(RegExp(r'\s+'))) {
      return null;
    }

    final tokens = query
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .where((token) => !_commonNoiseTokens.contains(token))
        .toList();
    if (tokens.length != 1) {
      return null;
    }

    return 'https://${tokens.first}.com'.normalizeWebsiteUrl();
  }

  static Future<List<String>> _probeCandidateWebsites(String query) async {
    final candidates = _buildWebsiteCandidatesFromQuery(query);
    final verified = <String>[];

    for (final website in candidates) {
      final isReachable = await _looksLikeLiveWebsite(website);
      if (!isReachable) {
        continue;
      }
      verified.add(website);
      if (verified.length >= 3) {
        break;
      }
    }
    return verified;
  }

  static List<String> _buildWebsiteCandidatesFromQuery(String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where(
          (token) =>
              token.length >= 3 || _meaningfulShortDomainTokens.contains(token),
        )
        .where((token) => !_commonNoiseTokens.contains(token))
        .toList();
    if (tokens.isEmpty) {
      return [];
    }

    final coreTokens = tokens
        .where((token) => !_commonCompanySuffixTokens.contains(token))
        .toList();
    final primaryTokens = coreTokens.isNotEmpty ? coreTokens : tokens;

    final candidates = <String>{};

    void addDomain(String domain) {
      final normalized = 'https://$domain'.normalizeWebsiteUrl();
      if (normalized == null) {
        return;
      }
      candidates.add(normalized);
    }

    if (primaryTokens.length >= 2) {
      final first = primaryTokens[0];
      final second = primaryTokens[1];
      addDomain('$first$second.com');
      addDomain('$first-$second.com');
    }

    addDomain('${primaryTokens.first}.com');

    if (primaryTokens.length >= 3) {
      final combined = primaryTokens.take(3).join();
      addDomain('$combined.com');
    }

    return candidates.toList();
  }

  static Future<bool> _looksLikeLiveWebsite(String website) async {
    final normalizedUri = website.normalizeWebsiteUri();
    if (normalizedUri == null) {
      return false;
    }

    for (final uri in normalizedUri.buildWebsiteCandidates()) {
      final response = await uri.tryGet();
      if (response == null) {
        continue;
      }

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return true;
      }
    }
    return false;
  }

  static String _companyNameFromWebsite(String website) {
    final uri = Uri.tryParse(website);
    if (uri == null || uri.host.isEmpty) {
      return 'Unknown Company';
    }
    final host = uri.host.toLowerCase();
    final withoutWww = host.startsWith('www.') ? host.substring(4) : host;
    final mainSegment = withoutWww.split('.').first;
    final words = mainSegment
        .split('-')
        .where((word) => word.trim().isNotEmpty)
        .map(_capitalize)
        .toList();
    if (words.isEmpty) {
      return 'Unknown Company';
    }
    return words.join(' ');
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static const Set<String> _commonNoiseTokens = {
    'www',
    'http',
    'https',
    'com',
    'from',
    'text',
    'reply',
    'stop',
    'msg',
    'message',
    'verify',
    'code',
    'your',
    'account',
    'login',
  };

  static const Set<String> _commonCompanySuffixTokens = {
    'inc',
    'llc',
    'ltd',
    'corp',
    'co',
    'company',
    'bank',
    'services',
    'group',
  };

  static const Set<String> _meaningfulShortDomainTokens = {
    'hq',
    'ai',
    'io',
  };
}
