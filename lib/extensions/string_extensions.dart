import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_photos/extensions/http_extensions.dart';
import 'package:contact_photos/helpers/image_logo_helpers.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:http/http.dart' as http;

extension StringExtensions on String {
  List<CompanySearchResult> parseCompanies() {
    if (trim().isEmpty) {
      return [];
    }

    final jsonPayload = extractJsonPayload();
    if (jsonPayload == null) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonPayload);
      final items = decoded is Map<String, dynamic>
          ? decoded['companies']
          : decoded is List
              ? decoded
              : null;

      if (items is! List) return [];

      final seenWebsites = <String>{};
      final results = <CompanySearchResult>[];

      for (final item in items) {
        if (item is! Map) continue;
        final name = (item['name'] as String?)?.trim() ?? '';
        final website = (item['websiteUrl'] as String?)?.normalizeWebsiteUrl();
        if (name.isEmpty || website == null) continue;
        if (!seenWebsites.add(website)) continue;
        results.add(CompanySearchResult(name: name, websiteUrl: website));
        if (results.length >= 6) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  String? extractJsonPayload() {
    final trimmed = trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return trimmed;
    }

    final objectStart = trimmed.indexOf('{');
    final objectEnd = trimmed.lastIndexOf('}');
    if (objectStart >= 0 && objectEnd > objectStart) {
      return trimmed.substring(objectStart, objectEnd + 1);
    }
    return null;
  }

  String? normalizeWebsiteUrl() {
    final trimmed = trim();
    if (trimmed.isEmpty) return null;

    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return null;
    }
    return uri.toString();
  }

  bool isLikelyUiIconUrl() {
    final lower = toLowerCase();
    return lower.contains('icon-') ||
        lower.contains('/icons/') ||
        lower.contains('/icon/') ||
        lower.contains('glyph') ||
        lower.contains('sprite');
  }

  bool isLikelySvgUrl() {
    final lower = toLowerCase();
    return lower.contains('.svg') || lower.contains('format=svg');
  }

  List<String> extractUrlsFromSrcset() {
    if (trim().isEmpty) {
      return [];
    }

    final urls = <String>[];
    final candidates = split(',');
    for (final candidate in candidates) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        urls.add(parts.first);
      }
    }
    return urls;
  }

  Future<Uint8List?> downloadImageBytes({int depth = 0}) async {
    if (depth > 1) return null;

    try {
      final uri = Uri.parse(this);
      final response = await http.get(uri, headers: const {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      if (response.looksLikeImage()) {
        return response.bodyBytes;
      }

      if (response.looksLikeHtml()) {
        final extracted =
            ImageLogoHelpers.extractLogoImageUrlsFromHtml(response.body, uri);
        for (final candidate in extracted) {
          if (candidate == this) continue;
          if (candidate.isLikelySocialAssetUrl()) continue;
          final bytes = await candidate.downloadImageBytes(depth: depth + 1);
          if (bytes != null) {
            return bytes;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Uri? normalizeWebsiteUri() {
    final trimmed = trim();
    if (trimmed.isEmpty) return null;

    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return Uri(
      scheme: 'https',
      host: uri.host.toLowerCase(),
      path: uri.path.isEmpty ? '/' : uri.path,
    );
  }

  bool isLikelySocialAssetUrl() {
    final lower = toLowerCase();
    const socialHosts = [
      'facebook.com',
      'instagram.com',
      'cdninstagram.com',
      'fbcdn.net',
      'twitter.com',
      'x.com',
      'linkedin.com',
      'youtube.com',
      'ytimg.com',
      'tiktok.com',
      'pinterest.com',
    ];
    if (socialHosts.any(lower.contains)) {
      return true;
    }

    return lower.contains('social') ||
        lower.contains('instagram') ||
        lower.contains('facebook') ||
        lower.contains('linkedin') ||
        lower.contains('twitter') ||
        lower.contains('tiktok');
  }

  List<String> extractCompanyTokens() {
    final rawTokens = toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3);
    return rawTokens.toSet().toList();
  }

  String trimTrailingUrlPunctuation({bool removeDot = false}) {
    var end = length;
    while (end > 0) {
      final char = this[end - 1];
      final shouldTrim = char == ')' ||
          char == ',' ||
          char == ']' ||
          char == '>' ||
          (removeDot && char == '.');
      if (!shouldTrim) break;
      end--;
    }
    return substring(0, end);
  }

  List<String> extractHtmlStartTags(String tagName) {
    final tags = <String>[];
    final lowerHtml = toLowerCase();
    final needle = '<$tagName';
    var index = 0;

    while (true) {
      final start = lowerHtml.indexOf(needle, index);
      if (start == -1) break;
      final end = indexOf('>', start);
      if (end == -1) break;
      tags.add(substring(start, end + 1));
      index = end + 1;
    }
    return tags;
  }

  String? extractHtmlAttribute(String attributeName) {
    final lowerTag = toLowerCase();
    final lowerAttribute = attributeName.toLowerCase();
    var index = 0;

    while (true) {
      final attrIndex = lowerTag.indexOf(lowerAttribute, index);
      if (attrIndex == -1) return null;

      final before = attrIndex - 1;
      if (before >= 0) {
        final beforeChar = lowerTag[before];
        final validBoundary = beforeChar == ' ' ||
            beforeChar == '\n' ||
            beforeChar == '\t' ||
            beforeChar == '<';
        if (!validBoundary) {
          index = attrIndex + 1;
          continue;
        }
      }

      var equalsIndex = attrIndex + lowerAttribute.length;
      while (equalsIndex < length && this[equalsIndex].trim().isEmpty) {
        equalsIndex++;
      }

      if (equalsIndex >= length || this[equalsIndex] != '=') {
        index = attrIndex + 1;
        continue;
      }

      equalsIndex++;
      while (equalsIndex < length && this[equalsIndex].trim().isEmpty) {
        equalsIndex++;
      }
      if (equalsIndex >= length) return null;

      final quote = this[equalsIndex];
      if (quote == '"' || quote == '\'') {
        final valueStart = equalsIndex + 1;
        final valueEnd = indexOf(quote, valueStart);
        if (valueEnd == -1) return null;
        return substring(valueStart, valueEnd);
      }

      var valueEnd = equalsIndex;
      while (valueEnd < length) {
        final current = this[valueEnd];
        if (current == ' ' ||
            current == '\n' ||
            current == '\t' ||
            current == '>') {
          break;
        }
        valueEnd++;
      }
      return substring(equalsIndex, valueEnd);
    }
  }

  List<String> extractJsonLdLogoUrls() {
    final results = <String>{};
    final logoRegex = RegExp(
      r'"logo"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    );
    for (final match in logoRegex.allMatches(this)) {
      final raw = match.group(1);
      if (raw != null && raw.isNotEmpty) {
        results.add(raw);
      }
    }
    return results.toList();
  }

  String? extractDomainToken() {
    final uri = normalizeWebsiteUri();
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final withoutWww = host.startsWith('www.') ? host.substring(4) : host;
    final token = withoutWww.split('.').first;
    return token.isEmpty ? null : token;
  }

  String slugify() {
    final lower = toLowerCase();
    final normalized = lower
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized;
  }
}
