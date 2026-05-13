import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/extensions/uri_extensions.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

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
    final verified = <String>{};

    for (final website in candidates) {
      final resolvedWebsite = await resolveLiveWebsite(website);
      if (resolvedWebsite == null) {
        continue;
      }
      verified.add(resolvedWebsite);
      if (verified.length >= 3) {
        break;
      }
    }
    return verified.toList();
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

  @visibleForTesting
  static Future<String?> resolveLiveWebsite(
    String website, {
    http.Client? client,
  }) async {
    final normalizedUri = website.normalizeWebsiteUri();
    if (normalizedUri == null) {
      return null;
    }

    final ownedClient = client ?? http.Client();
    try {
      for (final uri in normalizedUri.buildWebsiteCandidates()) {
        final resolvedUri = await _resolveRedirectedWebsiteUri(
          uri,
          client: ownedClient,
        );
        final resolvedWebsite = resolvedUri?.toString().normalizeWebsiteUrl();
        if (resolvedWebsite != null) {
          return resolvedWebsite;
        }
      }
      return null;
    } finally {
      if (client == null) {
        ownedClient.close();
      }
    }
  }

  static Future<Uri?> _resolveRedirectedWebsiteUri(
    Uri startUri, {
    required http.Client client,
  }) async {
    var currentUri = startUri;

    for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
      http.StreamedResponse response;
      try {
        final request = http.Request('GET', currentUri)
          ..followRedirects = false
          ..maxRedirects = 0
          ..headers.addAll(const {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          });
        response =
            await client.send(request).timeout(const Duration(seconds: 6));
      } catch (_) {
        return null;
      }

      try {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return currentUri;
        }

        final location = response.headers['location'];
        final isRedirect =
            response.statusCode >= 300 && response.statusCode < 400;
        if (!isRedirect || location == null || location.isEmpty) {
          return null;
        }

        currentUri = currentUri.resolve(location);
      } finally {
        await response.stream.drain<void>();
      }
    }

    return null;
  }

  static String _companyNameFromWebsite(String website) {
    return website.inferCompanyNameFromWebsite();
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
