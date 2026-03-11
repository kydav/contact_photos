import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;

class CompanyImageOption {
  const CompanyImageOption({
    required this.url,
    required this.bytes,
  });

  final String url;
  final Uint8List bytes;
}

typedef CompanyImageSelectedCallback = void Function(String imageUrl);

class CompanyImageQueryWidget extends HookWidget {
  const CompanyImageQueryWidget({
    super.key,
    required this.companyName,
    required this.companyWebsiteUrl,
    required this.onImageSelected,
  });

  final String companyName;
  final String companyWebsiteUrl;
  final CompanyImageSelectedCallback onImageSelected;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    final errorText = useState<String?>(null);
    final imageOptions = useState<List<CompanyImageOption>>([]);

    Future<void> searchCompanyImages() async {
      isLoading.value = true;
      errorText.value = null;
      imageOptions.value = [];

      try {
        final urls = await _queryImageUrlsFromWebsite(
          companyName: companyName,
          websiteUrl: companyWebsiteUrl,
        );

        imageOptions.value = await _loadRenderableImageOptions(urls);
        if (imageOptions.value.isEmpty) {
          errorText.value =
              'No renderable images found from website metadata or assets.';
        }
      } catch (error) {
        errorText.value = 'Could not search company images: $error';
      } finally {
        isLoading.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Company Images',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text('Company: $companyName'),
        Text('Website: $companyWebsiteUrl'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isLoading.value ? null : searchCompanyImages,
          icon: const Icon(Icons.image_search),
          label: const Text('Search images'),
        ),
        if (isLoading.value) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (errorText.value != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (imageOptions.value.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageOptions.value.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final imageOption = imageOptions.value[index];
                return SizedBox(
                  width: 170,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                imageOption.bytes,
                                fit: BoxFit.contain,
                                width: double.infinity,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => onImageSelected(imageOption.url),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

Future<List<String>> _queryImageUrlsFromWebsite({
  required String companyName,
  required String websiteUrl,
}) async {
  final baseUri = _normalizeWebsiteUri(websiteUrl);
  if (baseUri == null) {
    throw Exception('Invalid company website URL.');
  }

  final websiteUris = _buildWebsiteCandidates(baseUri);
  final companyTokens = _extractCompanyTokens(companyName);
  final discoveredUrls = <String>{};

  for (final websiteUri in websiteUris) {
    discoveredUrls.addAll(_buildCommonImageAssetUrls(websiteUri));

    final response = await _tryGet(websiteUri);
    if (response == null || response.bodyBytes.isEmpty) {
      continue;
    }

    if (_responseLooksLikeImage(response)) {
      discoveredUrls.add(websiteUri.toString());
      continue;
    }

    if (_responseLooksLikeHtml(response)) {
      discoveredUrls.addAll(
        _extractLogoImageUrlsFromHtml(
          response.body,
          websiteUri,
          companyTokens: companyTokens,
        ),
      );
    }
  }

  final rankedUrls = _rankImageCandidates(
    discoveredUrls.toList(),
    websiteUris.first.host,
    companyTokens,
  );

  return rankedUrls.take(24).toList();
}

Uri? _normalizeWebsiteUri(String websiteUrl) {
  final trimmed = websiteUrl.trim();
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

List<Uri> _buildWebsiteCandidates(Uri baseUri) {
  final candidates = <Uri>{};
  final host = baseUri.host;

  candidates.add(Uri(scheme: 'https', host: host, path: '/'));

  if (host.startsWith('www.')) {
    final noWww = host.substring(4);
    if (noWww.isNotEmpty && noWww.contains('.')) {
      candidates.add(Uri(scheme: 'https', host: noWww, path: '/'));
    }
  } else {
    candidates.add(Uri(scheme: 'https', host: 'www.$host', path: '/'));
  }

  return candidates.toList();
}

List<String> _buildCommonImageAssetUrls(Uri websiteUri) {
  final urls = <String>{
    Uri(scheme: 'https', host: websiteUri.host, path: '/favicon.ico')
        .toString(),
    Uri(
      scheme: 'https',
      host: websiteUri.host,
      path: '/apple-touch-icon.png',
    ).toString(),
    Uri(
      scheme: 'https',
      host: websiteUri.host,
      path: '/apple-touch-icon-precomposed.png',
    ).toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/logo.png').toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/images/logo.png')
        .toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/images/logo.jpg')
        .toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/images/logo.webp')
        .toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/assets/logo.png')
        .toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/assets/img/logo.png')
        .toString(),
    Uri(
      scheme: 'https',
      host: websiteUri.host,
      path: '/assets/images/logo.png',
    ).toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/media/logo.png')
        .toString(),
    Uri(scheme: 'https', host: websiteUri.host, path: '/themes/logo.png')
        .toString(),
    'https://www.google.com/s2/favicons?sz=256&domain_url=https://${websiteUri.host}',
  };
  return urls.toList();
}

Future<http.Response?> _tryGet(Uri uri) async {
  try {
    return await http.get(uri, headers: const {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    }).timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
}

bool _responseLooksLikeImage(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  if (contentType.contains('svg')) {
    return false;
  }
  return contentType.startsWith('image/') ||
      _looksLikeImageBytes(response.bodyBytes);
}

bool _responseLooksLikeHtml(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  if (contentType.contains('text/html')) {
    return true;
  }
  final trimmedBody = response.body.trimLeft();
  return trimmedBody.startsWith('<!doctype html') ||
      trimmedBody.startsWith('<html');
}

List<String> _extractLogoImageUrlsFromHtml(
  String html,
  Uri baseUri, {
  List<String> companyTokens = const [],
}) {
  final urls = <String>{};

  void addCandidate(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final cleaned = _trimTrailingUrlPunctuation(
      rawValue.replaceAll('&amp;', '&').trim(),
      removeDot: true,
    );
    if (cleaned.isEmpty || cleaned.startsWith('data:')) return;

    final absolute = baseUri.resolve(cleaned).toString();
    final uri = Uri.tryParse(absolute);
    if (uri == null || uri.host.isEmpty) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    if (_isLikelySvgUrl(absolute)) return;
    if (_isLikelySocialAssetUrl(absolute)) return;

    urls.add(uri.toString());
  }

  for (final tag in _extractHtmlStartTags(html, 'meta')) {
    final property = _extractHtmlAttribute(tag, 'property')?.toLowerCase();
    final name = _extractHtmlAttribute(tag, 'name')?.toLowerCase();
    final isImageMeta = property == 'og:image' ||
        property == 'og:image:url' ||
        name == 'twitter:image' ||
        name == 'twitter:image:src' ||
        _extractHtmlAttribute(tag, 'itemprop')?.toLowerCase() == 'logo';
    if (!isImageMeta) continue;
    addCandidate(_extractHtmlAttribute(tag, 'content'));
  }

  for (final logoUrl in _extractJsonLdLogoUrls(html)) {
    addCandidate(logoUrl);
  }

  for (final tag in _extractHtmlStartTags(html, 'link')) {
    final rel = _extractHtmlAttribute(tag, 'rel')?.toLowerCase() ?? '';
    if (rel.contains('icon')) {
      addCandidate(_extractHtmlAttribute(tag, 'href'));
    }
  }

  for (final tag in _extractHtmlStartTags(html, 'img')) {
    final lowered = tag.toLowerCase();
    final alt = (_extractHtmlAttribute(tag, 'alt') ?? '').toLowerCase();
    final className = (_extractHtmlAttribute(tag, 'class') ?? '').toLowerCase();
    final markerText = '$lowered $alt $className';
    final tokenMatch = companyTokens.any(markerText.contains);
    if (!markerText.contains('logo') &&
        !markerText.contains('brand') &&
        !markerText.contains('header') &&
        !tokenMatch) {
      continue;
    }

    addCandidate(_extractHtmlAttribute(tag, 'src'));
    addCandidate(_extractHtmlAttribute(tag, 'data-src'));
    for (final srcsetUrl in _extractUrlsFromSrcset(
      _extractHtmlAttribute(tag, 'srcset'),
    )) {
      addCandidate(srcsetUrl);
    }
  }

  return urls.toList();
}

List<String> _extractUrlsFromSrcset(String? srcset) {
  if (srcset == null || srcset.trim().isEmpty) {
    return [];
  }

  final urls = <String>[];
  final candidates = srcset.split(',');
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

List<String> _extractCompanyTokens(String companyName) {
  final rawTokens = companyName
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 3);
  return rawTokens.toSet().toList();
}

List<String> _rankImageCandidates(
  List<String> urls,
  String primaryHost,
  List<String> companyTokens,
) {
  int score(String url) {
    final lower = url.toLowerCase();
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    var value = 0;

    if (_isLikelySocialAssetUrl(url)) {
      value -= 24;
    }
    if (host == primaryHost || host == 'www.$primaryHost') {
      value += 5;
    }
    if (lower.contains('logo')) value += 4;
    if (lower.contains('brand')) value += 2;
    if (lower.contains('icon') || lower.contains('favicon')) value += 2;
    if (_isLikelyUiIconUrl(url)) value -= 8;
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

Future<List<CompanyImageOption>> _loadRenderableImageOptions(
  List<String> urls,
) async {
  final results = <CompanyImageOption>[];
  for (final url in urls) {
    if (_isLikelySocialAssetUrl(url)) continue;
    final bytes = await _downloadImageBytes(url);
    if (bytes == null) continue;
    results.add(CompanyImageOption(url: url, bytes: bytes));
    if (results.length >= 8) break;
  }
  return results;
}

Future<Uint8List?> _downloadImageBytes(
  String imageUrl, {
  int depth = 0,
}) async {
  if (depth > 2) return null;

  try {
    final uri = Uri.parse(imageUrl);
    final response = await http.get(uri, headers: const {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }

    if (_responseLooksLikeImage(response)) {
      return response.bodyBytes;
    }

    if (_responseLooksLikeHtml(response)) {
      final extracted = _extractLogoImageUrlsFromHtml(response.body, uri);
      for (final candidate in extracted) {
        if (candidate == imageUrl) continue;
        if (_isLikelySocialAssetUrl(candidate)) continue;
        final bytes = await _downloadImageBytes(candidate, depth: depth + 1);
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

bool _isLikelySvgUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.svg') || lower.contains('format=svg');
}

List<String> _extractJsonLdLogoUrls(String html) {
  final results = <String>{};
  final logoRegex = RegExp(
    r'"logo"\s*:\s*"([^"]+)"',
    caseSensitive: false,
  );
  for (final match in logoRegex.allMatches(html)) {
    final raw = match.group(1);
    if (raw != null && raw.isNotEmpty) {
      results.add(raw);
    }
  }
  return results.toList();
}

bool _isLikelySocialAssetUrl(String url) {
  final lower = url.toLowerCase();
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

bool _isLikelyUiIconUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('icon-') ||
      lower.contains('/icons/') ||
      lower.contains('/icon/') ||
      lower.contains('glyph') ||
      lower.contains('sprite');
}

bool _looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;

  final isPng = bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
  final isGif = bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38;
  final isWebp = bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
  final isIco = bytes[0] == 0x00 &&
      bytes[1] == 0x00 &&
      bytes[2] == 0x01 &&
      bytes[3] == 0x00;

  return isPng || isJpeg || isGif || isWebp || isIco;
}

String _trimTrailingUrlPunctuation(String value, {bool removeDot = false}) {
  var end = value.length;
  while (end > 0) {
    final char = value[end - 1];
    final shouldTrim = char == ')' ||
        char == ',' ||
        char == ']' ||
        char == '>' ||
        (removeDot && char == '.');
    if (!shouldTrim) break;
    end--;
  }
  return value.substring(0, end);
}

List<String> _extractHtmlStartTags(String html, String tagName) {
  final tags = <String>[];
  final lowerHtml = html.toLowerCase();
  final needle = '<$tagName';
  var index = 0;

  while (true) {
    final start = lowerHtml.indexOf(needle, index);
    if (start == -1) break;
    final end = html.indexOf('>', start);
    if (end == -1) break;
    tags.add(html.substring(start, end + 1));
    index = end + 1;
  }
  return tags;
}

String? _extractHtmlAttribute(String tag, String attributeName) {
  final lowerTag = tag.toLowerCase();
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
    while (equalsIndex < tag.length && tag[equalsIndex].trim().isEmpty) {
      equalsIndex++;
    }

    if (equalsIndex >= tag.length || tag[equalsIndex] != '=') {
      index = attrIndex + 1;
      continue;
    }

    equalsIndex++;
    while (equalsIndex < tag.length && tag[equalsIndex].trim().isEmpty) {
      equalsIndex++;
    }
    if (equalsIndex >= tag.length) return null;

    final quote = tag[equalsIndex];
    if (quote == '"' || quote == '\'') {
      final valueStart = equalsIndex + 1;
      final valueEnd = tag.indexOf(quote, valueStart);
      if (valueEnd == -1) return null;
      return tag.substring(valueStart, valueEnd);
    }

    var valueEnd = equalsIndex;
    while (valueEnd < tag.length) {
      final current = tag[valueEnd];
      if (current == ' ' ||
          current == '\n' ||
          current == '\t' ||
          current == '>') {
        break;
      }
      valueEnd++;
    }
    return tag.substring(equalsIndex, valueEnd);
  }
}
