import 'dart:core';

import 'package:contact_photos/extensions/http_extensions.dart';
import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/extensions/uri_extensions.dart';
import 'package:contact_photos/models/company_image_option.dart';

class ImageLogoHelpers {
  static List<String> rankImageCandidates(
    List<String> urls,
    String primaryHost,
    List<String> companyTokens,
  ) {
    int score(String url) {
      final lower = url.toLowerCase();
      final uri = Uri.tryParse(url);
      final host = uri?.host.toLowerCase() ?? '';
      var value = 0;

      if (url.isLikelySocialAssetUrl()) {
        value -= 24;
      }
      if (host == primaryHost || host == 'www.$primaryHost') {
        value += 5;
      }
      if (lower.contains('logo')) value += 4;
      if (lower.contains('brand')) value += 2;
      if (lower.contains('icon') || lower.contains('favicon')) value += 2;
      if (url.isLikelyUiIconUrl()) value -= 8;
      if (lower.contains('sprite') ||
          lower.contains('placeholder') ||
          lower.contains('blank')) {
        value -= 6;
      }

      for (final token in companyTokens) {
        if (lower.contains(token)) {
          value += 2;
        }
      }

      return value;
    }

    final deduped = <String>{...urls}.toList();
    deduped.sort((a, b) => score(b).compareTo(score(a)));
    return deduped;
  }

  static List<String> extractLogoImageUrlsFromHtml(
    String html,
    Uri baseUri, {
    List<String> companyTokens = const [],
    bool allowSocialAssetUrls = false,
  }) {
    final urls = <String>{};

    void addCandidate(String? rawValue) {
      if (rawValue == null || rawValue.trim().isEmpty) return;

      final cleaned =
          rawValue.replaceAll('&amp;', '&').trim().trimTrailingUrlPunctuation(
                removeDot: true,
              );
      if (cleaned.isEmpty || cleaned.startsWith('data:')) return;

      final absolute = baseUri.resolve(cleaned).toString();
      final uri = Uri.tryParse(absolute);
      if (uri == null || uri.host.isEmpty) return;
      if (uri.scheme != 'http' && uri.scheme != 'https') return;
      if (absolute.isLikelySvgUrl()) return;
      if (!allowSocialAssetUrls && absolute.isLikelySocialAssetUrl()) return;

      urls.add(uri.toString());
    }

    for (final tag in html.extractHtmlStartTags('meta')) {
      final property = tag.extractHtmlAttribute('property')?.toLowerCase();
      final name = tag.extractHtmlAttribute('name')?.toLowerCase();
      final isImageMeta = property == 'og:image' ||
          property == 'og:image:url' ||
          name == 'twitter:image' ||
          name == 'twitter:image:src' ||
          tag.extractHtmlAttribute('itemprop')?.toLowerCase() == 'logo';
      if (!isImageMeta) continue;
      addCandidate(tag.extractHtmlAttribute('content'));
    }

    html.extractJsonLdLogoUrls().forEach(addCandidate);

    for (final tag in html.extractHtmlStartTags('link')) {
      final rel = tag.extractHtmlAttribute('rel')?.toLowerCase() ?? '';
      if (rel.contains('icon')) {
        addCandidate(tag.extractHtmlAttribute('href'));
      }
    }

    for (final tag in html.extractHtmlStartTags('img')) {
      final lowered = tag.toLowerCase();
      final alt = (tag.extractHtmlAttribute('alt') ?? '').toLowerCase();
      final className = (tag.extractHtmlAttribute('class') ?? '').toLowerCase();
      final markerText = '$lowered $alt $className';
      final tokenMatch = companyTokens.any(markerText.contains);
      if (!markerText.contains('logo') &&
          !markerText.contains('brand') &&
          !markerText.contains('header') &&
          !tokenMatch) {
        continue;
      }

      addCandidate(tag.extractHtmlAttribute('src'));
      addCandidate(tag.extractHtmlAttribute('data-src'));
      (tag.extractHtmlAttribute('srcset') ?? '')
          .extractUrlsFromSrcset()
          .forEach(addCandidate);
    }

    return urls.toList();
  }

  static Future<List<CompanyImageOption>> loadRenderableImageOptions(
    List<String> urls, {
    void Function(int completed, int total)? onProgress,
    bool allowSocialAssetUrls = false,
  }) async {
    final candidateUrls = urls.take(16).toList();
    final results = <CompanyImageOption>[];
    final total = candidateUrls.length;
    var completed = 0;
    onProgress?.call(0, total);

    const chunkSize = 4;
    for (var start = 0; start < candidateUrls.length; start += chunkSize) {
      if (results.length >= 8) {
        break;
      }

      final end = (start + chunkSize < candidateUrls.length)
          ? start + chunkSize
          : candidateUrls.length;
      final chunk = candidateUrls.sublist(start, end);

      final futures = chunk
          .map((url) async => (url: url, bytes: await url.downloadImageBytes()))
          .toList();
      final resolved = await Future.wait(futures);

      for (final item in resolved) {
        completed += 1;
        onProgress?.call(completed, total);

        final url = item.url;
        final bytes = item.bytes;
        if (!allowSocialAssetUrls && url.isLikelySocialAssetUrl()) continue;
        if (bytes == null) continue;

        results.add(CompanyImageOption(url: url, bytes: bytes));
        if (results.length >= 8) {
          break;
        }
      }
    }

    if (total == 0) {
      onProgress?.call(0, 0);
    }
    return results;
  }

  static List<CompanyImageOption> mergeImageOptions(
    List<CompanyImageOption> primary,
    List<CompanyImageOption> additional,
  ) {
    final merged = <CompanyImageOption>[];
    final seen = <String>{};

    for (final option in [...primary, ...additional]) {
      if (!seen.add(option.url)) {
        continue;
      }
      merged.add(option);
      if (merged.length >= 8) {
        break;
      }
    }
    return merged;
  }

  static Future<List<String>> queryImageUrlsFromWebsite({
    required String companyName,
    required String websiteUrl,
  }) async {
    final baseUri = websiteUrl.normalizeWebsiteUri();
    if (baseUri == null) {
      throw Exception('Invalid company website URL.');
    }

    final websiteUris = baseUri.buildWebsiteCandidates();
    final companyTokens = companyName.extractCompanyTokens();
    final discoveredUrls = <String>{};

    final primaryHost = websiteUris.first.host.toLowerCase();
    final domainForLogoApi =
        primaryHost.startsWith('www.') ? primaryHost.substring(4) : primaryHost;
    discoveredUrls.add(
      Uri.parse('https://logos-api.apistemic.com/domain:$domainForLogoApi')
          .toString(),
    );

    for (final websiteUri in websiteUris) {
      discoveredUrls.addAll(websiteUri.buildCommonImageAssetUrls());

      final response = await websiteUri.tryGet();
      if (response == null || response.bodyBytes.isEmpty) {
        continue;
      }

      if (response.looksLikeImage()) {
        discoveredUrls.add(websiteUri.toString());
        continue;
      }

      if (response.looksLikeHtml()) {
        discoveredUrls.addAll(
          ImageLogoHelpers.extractLogoImageUrlsFromHtml(
            response.body,
            websiteUri,
            companyTokens: companyTokens,
          ),
        );
      }
    }

    final rankedUrls = ImageLogoHelpers.rankImageCandidates(
      discoveredUrls.toList(),
      primaryHost,
      companyTokens,
    );

    return rankedUrls.take(24).toList();
  }

  static Future<List<String>> queryImageUrlsFromLogosWorld({
    required String companyName,
    required String companyWebsiteUrl,
  }) async {
    final pageUris = ImageLogoHelpers.buildLogosWorldPageUris(
      companyName: companyName,
      companyWebsiteUrl: companyWebsiteUrl,
    );
    if (pageUris.isEmpty) {
      return [];
    }

    final companyTokens = companyName.extractCompanyTokens();
    final discoveredUrls = <String>{};

    final responses =
        await Future.wait(pageUris.map((uri) => uri.tryGet()).toList());
    for (var i = 0; i < responses.length; i++) {
      final response = responses[i];
      if (response == null ||
          response.statusCode != 200 ||
          response.bodyBytes.isEmpty) {
        continue;
      }

      final pageUri = pageUris[i];
      if (response.looksLikeImage()) {
        discoveredUrls.add(pageUri.toString());
        continue;
      }

      if (response.looksLikeHtml()) {
        discoveredUrls.addAll(
          ImageLogoHelpers.extractLogoImageUrlsFromHtml(
            response.body,
            pageUri,
            companyTokens: companyTokens,
          ),
        );
      }
    }

    final ranked = ImageLogoHelpers.rankImageCandidates(
      discoveredUrls.toList(),
      'logos-world.net',
      companyTokens,
    );
    return ranked.take(12).toList();
  }

  static Future<List<String>> queryImageUrlsFromSocialProfiles({
    required String companyName,
    required String companyWebsiteUrl,
  }) async {
    final websiteUri = companyWebsiteUrl.normalizeWebsiteUri();
    if (websiteUri == null) {
      return [];
    }

    final companyTokens = companyName.extractCompanyTokens();
    final profileUris = <Uri>{};

    final websiteCandidates = websiteUri.buildWebsiteCandidates();
    for (final candidateUri in websiteCandidates) {
      final response = await candidateUri.tryGet();
      if (response == null || response.bodyBytes.isEmpty) {
        continue;
      }
      if (!response.looksLikeHtml()) {
        continue;
      }

      profileUris.addAll(
        _extractSocialProfileUrisFromHtml(response.body, candidateUri),
      );
    }

    profileUris.addAll(
      ImageLogoHelpers.buildGuessedSocialProfileUris(
        companyName: companyName,
        companyWebsiteUrl: companyWebsiteUrl,
      ),
    );

    if (profileUris.isEmpty) {
      return [];
    }

    final discoveredUrls = <String>{};
    final responses =
        await Future.wait(profileUris.map((uri) => uri.tryGet()).toList());

    for (var i = 0; i < responses.length; i++) {
      final response = responses[i];
      if (response == null ||
          response.statusCode != 200 ||
          response.bodyBytes.isEmpty) {
        continue;
      }

      final profileUri = profileUris.elementAt(i);
      if (response.looksLikeImage()) {
        discoveredUrls.add(profileUri.toString());
        continue;
      }

      if (response.looksLikeHtml()) {
        discoveredUrls.addAll(
          ImageLogoHelpers.extractLogoImageUrlsFromHtml(
            response.body,
            profileUri,
            companyTokens: companyTokens,
            allowSocialAssetUrls: true,
          ),
        );
      }
    }

    final ranked = ImageLogoHelpers.rankImageCandidates(
      discoveredUrls.toList(),
      websiteUri.host,
      companyTokens,
    );
    return ranked.take(12).toList();
  }

  static Set<Uri> _extractSocialProfileUrisFromHtml(String html, Uri baseUri) {
    final profileUris = <Uri>{};
    for (final tag in html.extractHtmlStartTags('a')) {
      final href = tag.extractHtmlAttribute('href');
      if (href == null || href.trim().isEmpty) {
        continue;
      }

      final resolved = baseUri.resolve(href.trim());
      final host = resolved.host.toLowerCase();
      final isSocialProfile = host.contains('facebook.com') ||
          host.contains('instagram.com') ||
          host.contains('m.facebook.com') ||
          host.contains('m.instagram.com');
      if (!isSocialProfile) {
        continue;
      }

      if (resolved.path.contains('/share') ||
          resolved.path.contains('/sharer')) {
        continue;
      }

      profileUris.add(
        Uri(
          scheme: 'https',
          host: resolved.host,
          path: resolved.path,
          query: resolved.query,
        ),
      );
    }
    return profileUris;
  }

  static List<Uri> buildGuessedSocialProfileUris({
    required String companyName,
    required String companyWebsiteUrl,
  }) {
    final slugs = <String>{};
    final fullSlug = companyName.slugify();
    if (fullSlug.isNotEmpty) {
      slugs.add(fullSlug);
      slugs.add(fullSlug.replaceAll('-', ''));
    }

    final tokens = companyName.extractCompanyTokens();
    if (tokens.isNotEmpty) {
      slugs.add(tokens.join());
      slugs.add(tokens.join('-'));
    }

    final domainToken = companyWebsiteUrl.extractDomainToken();
    if (domainToken != null && domainToken.isNotEmpty) {
      slugs.add(domainToken.slugify());
    }

    final cleanedSlugs = slugs
        .map((slug) => slug.replaceAll(RegExp('-+'), '-'))
        .where((slug) => slug.isNotEmpty)
        .take(6)
        .toList();

    final uris = <Uri>[];
    for (final slug in cleanedSlugs) {
      uris.add(Uri.parse('https://www.facebook.com/$slug'));
      uris.add(Uri.parse('https://m.facebook.com/$slug'));
      uris.add(Uri.parse('https://www.instagram.com/$slug/'));
    }
    return uris;
  }

  static List<Uri> buildLogosWorldPageUris({
    required String companyName,
    required String companyWebsiteUrl,
  }) {
    final slugCandidates = <String>{};
    final nameTokens = companyName.extractCompanyTokens();

    final fullSlug = companyName.slugify();
    if (fullSlug.isNotEmpty) {
      slugCandidates.add(fullSlug);
    }

    if (nameTokens.isNotEmpty) {
      slugCandidates.add(nameTokens.join('-'));
    }
    if (nameTokens.length >= 2) {
      slugCandidates.add('${nameTokens.first}-${nameTokens[1]}');
    }

    final websiteHost = companyWebsiteUrl.extractDomainToken();
    if (websiteHost != null && websiteHost.isNotEmpty) {
      slugCandidates.add(websiteHost.slugify());
    }

    final cleanedCandidates = slugCandidates
        .map((slug) => slug.replaceAll(RegExp('-+'), '-'))
        .where((slug) => slug.isNotEmpty)
        .take(6);

    return cleanedCandidates
        .map((slug) => Uri.parse('https://logos-world.net/$slug-logo/'))
        .toList();
  }
}
