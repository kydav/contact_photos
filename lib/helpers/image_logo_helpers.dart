import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:contact_photos/extensions/byte_extensions.dart';
import 'package:contact_photos/extensions/http_extensions.dart';
import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/extensions/uri_extensions.dart';
import 'package:contact_photos/helpers/app_secrets.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:http/http.dart' as http;

class ImageLogoHelpers {
  static const bool _enablePerIndexLogging = true;
  static const Set<String> _commonCompactDomainSuffixes = {
    'bank',
    'care',
    'cookies',
    'group',
    'health',
    'labs',
    'services',
    'systems',
  };

  static const Duration _candidateDownloadTimeout = Duration(seconds: 10);
  static const Duration _candidateProcessingTimeout = Duration(seconds: 3);
  static const Duration _candidateAttemptTimeout = Duration(seconds: 15);
  static const Duration _overallValidationTimeout = Duration(seconds: 75);
  static const Duration _downloadStreamStallTimeout = Duration(seconds: 3);
  static const int _maxDownloadedBytes = 8 * 1024 * 1024;

  static bool _allowsMetaWildcardCdnUrls(String companyName) {
    final lower = companyName.toLowerCase();
    return lower.contains('facebook') ||
        lower.contains('instagram') ||
        lower.contains('meta');
  }

  static bool _allowsSocialAssetUrlsForCompany(String companyName) {
    final lower = companyName.toLowerCase();
    return lower == 'x' ||
        lower.contains(' x ') ||
        lower.startsWith('x ') ||
        lower.endsWith(' x') ||
        lower.contains('twitter') ||
        lower.contains('facebook') ||
        lower.contains('instagram') ||
        lower.contains('meta');
  }

  static bool _isMetaWildcardCdnUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('fbcdn') || lower.contains('cdninstagram');
  }

  static bool _isDisallowedLogosWorldAssetUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    final host = uri.host.toLowerCase();
    if (host != 'logos-world.net' && host != 'www.logos-world.net') {
      return false;
    }

    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return RegExp(
      r'^logos-world\.net_\d+\.(png|jpe?g|webp)$',
      caseSensitive: false,
    ).hasMatch(lastSegment);
  }

  static List<String> _removeDisallowedMetaWildcardCdnUrls(
    Iterable<String> urls, {
    required bool allowMetaWildcardCdnUrls,
  }) {
    if (allowMetaWildcardCdnUrls) {
      return urls.toList();
    }
    return urls.where((url) => !_isMetaWildcardCdnUrl(url)).toList();
  }

  static List<String> rankImageCandidates(
      List<String> urls, String primaryHost, List<String> companyTokens,
      {bool allowSocialAssetUrls = false}) {
    int score(String url) {
      final lower = url.toLowerCase();
      final uri = Uri.tryParse(url);
      final host = uri?.host.toLowerCase() ?? '';
      var value = 0;

      if (!allowSocialAssetUrls && url.isLikelySocialAssetUrl()) {
        value -= 24;
      }
      if (_isTrustedLogoProviderHost(host)) {
        value += 12;
      }
      if (host == primaryHost || host == 'www.$primaryHost') {
        value += 5;
      }
      if (lower.contains('logo')) value += 4;
      if (lower.contains('brand')) value += 2;
      if (lower.contains('favicon')) value += 6;
      if (lower.contains('apple-touch-icon')) value += 5;
      if (lower.contains('android-chrome')) value += 4;
      if (lower.contains('icon')) value += 2;
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

  static bool _isTrustedLogoProviderHost(String host) {
    return host == 'img.logokit.com' || host == 'logos-api.apistemic.com';
  }

  static List<String> _prioritizeProviderCandidates(
    List<String> rankedUrls,
    List<Uri> providerUris, {
    int limit = 24,
  }) {
    final selected = rankedUrls.take(limit).toList();
    if (selected.length >= limit && providerUris.isEmpty) {
      return selected;
    }

    final selectedSet = selected.toSet();
    for (final providerUri in providerUris) {
      final providerUrl = providerUri.toString();
      if (selectedSet.contains(providerUrl)) {
        continue;
      }
      if (!rankedUrls.contains(providerUrl)) {
        continue;
      }

      if (selected.length >= limit) {
        selectedSet.remove(selected.removeLast());
      }
      selected.add(providerUrl);
      selectedSet.add(providerUrl);
    }

    return selected;
  }

  static List<String> extractLogoImageUrlsFromHtml(
    String html,
    Uri baseUri, {
    List<String> companyTokens = const [],
    bool allowSocialAssetUrls = false,
    bool allowMetaWildcardCdnUrls = false,
  }) {
    final urls = <String>{};

    void addCandidate(String? rawValue) {
      if (rawValue == null || rawValue.trim().isEmpty) return;

      final cleaned = rawValue
          .replaceAll('&amp;', '&')
          .trim()
          .trimTrailingUrlPunctuation(removeDot: true);
      if (cleaned.isEmpty || cleaned.startsWith('data:')) return;

      final absolute = baseUri.resolve(cleaned).toString();
      final uri = Uri.tryParse(absolute);
      if (uri == null || uri.host.isEmpty) return;
      if (uri.scheme != 'http' && uri.scheme != 'https') return;
      if (absolute.isLikelySvgUrl()) return;
      if (_isDisallowedLogosWorldAssetUrl(absolute)) return;
      if (!allowMetaWildcardCdnUrls && _isMetaWildcardCdnUrl(absolute)) return;
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
    bool excludePlatformBrandLogos = true,
  }) async {
    final candidateUrls = urls.take(16).toList();
    final results = <CompanyImageOption>[];
    final total = candidateUrls.length;
    var completed = 0;
    onProgress?.call(0, total);
    final stopwatch = Stopwatch()..start();

    for (var index = 0; index < candidateUrls.length; index++) {
      final url = candidateUrls[index];
      if (results.length >= 8) {
        break;
      }
      if (stopwatch.elapsed >= _overallValidationTimeout) {
        break;
      }

      final attemptStopwatch = Stopwatch()..start();
      _logCandidate(
        index: index,
        total: total,
        phase: 'start',
        url: url,
      );

      final attempt = await _buildCandidateOption(
        url,
        allowSocialAssetUrls: allowSocialAssetUrls,
      ).timeout(
        _candidateAttemptTimeout,
        onTimeout: () => (
          option: null,
          reason: 'candidate-timeout',
        ),
      );

      completed += 1;
      onProgress?.call(completed, total);

      _logCandidate(
        index: index,
        total: total,
        phase: 'complete',
        url: url,
        reason: attempt.reason,
        elapsedMs: attemptStopwatch.elapsedMilliseconds,
      );

      if (attempt.option != null) {
        results.add(attempt.option!);
      }
    }

    if (total == 0) {
      onProgress?.call(0, 0);
    }
    return results;
  }

  static Future<Uint8List?> _downloadDirectImageBytes(String url) async {
    final client = http.Client();
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        return null;
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      final request = http.Request('GET', uri)
        ..headers.addAll(const {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        });

      final response = await client.send(request).timeout(
            const Duration(seconds: 6),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final bytesBuilder = BytesBuilder(copy: false);
      var totalBytes = 0;
      await for (final chunk in response.stream.timeout(
        _downloadStreamStallTimeout,
      )) {
        totalBytes += chunk.length;
        if (totalBytes > _maxDownloadedBytes) {
          return null;
        }
        bytesBuilder.add(chunk);
      }

      final bytes = bytesBuilder.takeBytes();
      if (bytes.isEmpty) {
        return null;
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final looksLikeImage =
          (contentType.startsWith('image/') && !contentType.contains('svg')) ||
              bytes.looksLikeImageBytes();

      if (!looksLikeImage) {
        return null;
      }
      return bytes;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<bool> _shouldAcceptCandidate(
    String url,
    Uint8List? bytes, {
    required bool allowSocialAssetUrls,
    bool allowMetaWildcardCdnUrls = true,
  }) async {
    if (!allowMetaWildcardCdnUrls && _isMetaWildcardCdnUrl(url)) {
      return false;
    }
    if (_isDisallowedLogosWorldAssetUrl(url)) {
      return false;
    }
    if (!allowSocialAssetUrls && url.isLikelySocialAssetUrl()) {
      return false;
    }
    if (bytes == null) {
      return false;
    }

    return true;
  }

  static Future<({CompanyImageOption? option, String reason})>
      _buildCandidateOption(
    String url, {
    required bool allowSocialAssetUrls,
    bool allowMetaWildcardCdnUrls = true,
  }) async {
    var downloadTimedOut = false;
    final bytes = await _downloadDirectImageBytes(url).timeout(
      _candidateDownloadTimeout,
      onTimeout: () {
        downloadTimedOut = true;
        return null;
      },
    );
    if (downloadTimedOut) {
      return (option: null, reason: 'download-timeout');
    }
    if (bytes == null) {
      return (option: null, reason: 'download-null');
    }

    var processingTimedOut = false;
    final shouldAdd = await _shouldAcceptCandidate(
      url,
      bytes,
      allowSocialAssetUrls: allowSocialAssetUrls,
      allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
    ).timeout(
      _candidateProcessingTimeout,
      onTimeout: () {
        processingTimedOut = true;
        return false;
      },
    );
    if (processingTimedOut) {
      return (option: null, reason: 'processing-timeout');
    }

    if (!shouldAdd) {
      return (option: null, reason: 'filtered');
    }
    return (
      option: CompanyImageOption(url: url, bytes: bytes),
      reason: 'accepted',
    );
  }

  static void _logCandidate({
    required int index,
    required int total,
    required String phase,
    required String url,
    String? reason,
    int? elapsedMs,
  }) {
    if (!_enablePerIndexLogging) {
      return;
    }

    final reasonText = reason == null ? '' : ', reason=$reason';
    final elapsedText = elapsedMs == null ? '' : ', elapsed=${elapsedMs}ms';
    developer.log(
      '[image-check ${index + 1}/$total] $phase$reasonText$elapsedText, url=$url',
      name: 'ImageLogoHelpers',
    );
  }

  static void _logLogoUrls({
    required String source,
    required List<String> urls,
  }) {
    if (!_enablePerIndexLogging) {
      return;
    }

    for (var index = 0; index < urls.length; index++) {
      developer.log(
        '[logo-url ${index + 1}/${urls.length}] source=$source, url=${urls[index]}',
        name: 'ImageLogoHelpers',
      );
    }
  }

  static void _logSourceUris({
    required String source,
    required Iterable<Uri> uris,
  }) {
    if (!_enablePerIndexLogging) {
      return;
    }

    final uriList = uris.toList();
    for (var index = 0; index < uriList.length; index++) {
      developer.log(
        '[source-uri ${index + 1}/${uriList.length}] source=$source, uri=${_redactSensitiveUri(uriList[index])}',
        name: 'ImageLogoHelpers',
      );
    }
  }

  static Uri _redactSensitiveUri(Uri uri) {
    if (!uri.queryParameters.containsKey('token')) {
      return uri;
    }

    final redactedQuery = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key: entry.key == 'token' ? 'REDACTED' : entry.value,
    };

    return uri.replace(queryParameters: redactedQuery);
  }

  static void _logWebsiteProviderStatus({
    required String provider,
    required Uri? uri,
    required bool enabled,
    required List<String> rankedUrls,
    required List<String> selectedUrls,
    String? disabledReason,
  }) {
    if (!_enablePerIndexLogging) {
      return;
    }

    final redactedUri = uri == null ? null : _redactSensitiveUri(uri);
    final inRanked = uri != null && rankedUrls.contains(uri.toString());
    final inSelected = uri != null && selectedUrls.contains(uri.toString());

    developer.log(
      '[website-provider] provider=$provider, enabled=$enabled, '
      'ranked=$inRanked, selected=$inSelected, '
      'reason=${disabledReason ?? 'n/a'}, uri=${redactedUri ?? 'n/a'}',
      name: 'ImageLogoHelpers',
    );
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

  static Uri? buildLogokitLogoUri(
    String domain, {
    String? token,
  }) {
    final cleanedDomain = domain.trim().toLowerCase();
    if (cleanedDomain.isEmpty) {
      return null;
    }

    final effectiveToken = (token ?? AppSecrets.logokitApiKey).trim();
    if (effectiveToken.isEmpty) {
      return null;
    }

    return Uri.https(
      'img.logokit.com',
      cleanedDomain,
      {'token': effectiveToken},
    );
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
    final allowSocialAssetUrls = _allowsSocialAssetUrlsForCompany(companyName);
    final allowMetaWildcardCdnUrls = _allowsMetaWildcardCdnUrls(companyName);
    final discoveredUrls = <String>{};

    final primaryHost = websiteUris.first.host.toLowerCase();
    final domainForLogoApi =
        primaryHost.startsWith('www.') ? primaryHost.substring(4) : primaryHost;
    final logokitLogoUri = buildLogokitLogoUri(domainForLogoApi);
    final providerUris = <Uri>[];
    if (logokitLogoUri != null) {
      discoveredUrls.add(logokitLogoUri.toString());
      providerUris.add(logokitLogoUri);
    }
    final apistemicUri =
        Uri.parse('https://logos-api.apistemic.com/domain:$domainForLogoApi');
    discoveredUrls.add(apistemicUri.toString());
    providerUris.add(apistemicUri);
    _logSourceUris(source: 'website-provider', uris: providerUris);

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
            allowSocialAssetUrls: allowSocialAssetUrls,
            allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
          ),
        );
      }
    }
    var filteredUrls = discoveredUrls.toList();
    if (!allowSocialAssetUrls) {
      filteredUrls = ImageLogoHelpers._removeDisallowedMetaWildcardCdnUrls(
        discoveredUrls,
        allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
      );
    }

    final rankedUrls = ImageLogoHelpers.rankImageCandidates(
      filteredUrls,
      primaryHost,
      companyTokens,
      allowSocialAssetUrls: allowSocialAssetUrls,
    );
    final result = _prioritizeProviderCandidates(
      rankedUrls,
      providerUris,
    );
    _logWebsiteProviderStatus(
      provider: 'logokit',
      uri: logokitLogoUri,
      enabled: logokitLogoUri != null,
      rankedUrls: rankedUrls,
      selectedUrls: result,
      disabledReason: logokitLogoUri == null ? 'missing-api-key' : null,
    );
    _logWebsiteProviderStatus(
      provider: 'apistemic',
      uri: apistemicUri,
      enabled: true,
      rankedUrls: rankedUrls,
      selectedUrls: result,
    );
    _logLogoUrls(source: 'website', urls: result);
    return result;
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

    _logSourceUris(source: 'logos-world-page', uris: pageUris);

    final companyTokens = companyName.extractCompanyTokens();
    final allowSocialAssetUrls = _allowsSocialAssetUrlsForCompany(companyName);
    final allowMetaWildcardCdnUrls = _allowsMetaWildcardCdnUrls(companyName);
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
            allowSocialAssetUrls: allowSocialAssetUrls,
            allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
          ),
        );
      }
    }

    final filteredUrls = ImageLogoHelpers._removeDisallowedMetaWildcardCdnUrls(
      discoveredUrls,
      allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
    );

    final ranked = ImageLogoHelpers.rankImageCandidates(
      filteredUrls,
      'logos-world.net',
      companyTokens,
      allowSocialAssetUrls: allowSocialAssetUrls,
    );
    final result = ranked.take(12).toList();
    _logLogoUrls(source: 'logos-world', urls: result);
    return result;
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
    final allowMetaWildcardCdnUrls = _allowsMetaWildcardCdnUrls(companyName);
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
            allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
          ),
        );
      }
    }

    final filteredUrls = ImageLogoHelpers._removeDisallowedMetaWildcardCdnUrls(
      discoveredUrls,
      allowMetaWildcardCdnUrls: allowMetaWildcardCdnUrls,
    );

    final ranked = ImageLogoHelpers.rankImageCandidates(
      filteredUrls,
      websiteUri.host,
      companyTokens,
      allowSocialAssetUrls: true,
    );
    final result = ranked.take(12).toList();
    _logLogoUrls(source: 'social', urls: result);
    return result;
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

    void addSlugCandidate(String? rawSlug) {
      if (rawSlug == null || rawSlug.isEmpty) {
        return;
      }

      final cleaned = rawSlug.replaceAll(RegExp('-+'), '-');
      if (cleaned.isEmpty) {
        return;
      }
      slugCandidates.add(cleaned);
    }

    final fullSlug = companyName.slugify();
    if (fullSlug.isNotEmpty) {
      addSlugCandidate(fullSlug);
    }

    if (nameTokens.isNotEmpty) {
      addSlugCandidate(nameTokens.join('-'));
      addSlugCandidate(nameTokens.join());
    }
    if (nameTokens.length >= 2) {
      addSlugCandidate('${nameTokens.first}-${nameTokens[1]}');
      addSlugCandidate('${nameTokens.first}${nameTokens[1]}');
    }

    final websiteHost = companyWebsiteUrl.extractDomainToken();
    if (websiteHost != null && websiteHost.isNotEmpty) {
      addSlugCandidate(websiteHost.slugify());
      addSlugCandidate(websiteHost.replaceAll(RegExp('[^a-z0-9]+'), ''));

      final compactHost = websiteHost.replaceAll(RegExp('[^a-z0-9]+'), '');
      for (final suffix in _commonCompactDomainSuffixes) {
        if (!compactHost.endsWith(suffix) || compactHost == suffix) {
          continue;
        }

        final prefix =
            compactHost.substring(0, compactHost.length - suffix.length);
        if (prefix.length < 3) {
          continue;
        }

        addSlugCandidate('$prefix-$suffix');
      }
    }

    final cleanedCandidates = slugCandidates.where((slug) => slug.isNotEmpty);

    return cleanedCandidates
        .take(8)
        .map((slug) => Uri.parse('https://logos-world.net/$slug-logo/'))
        .toList();
  }
}
