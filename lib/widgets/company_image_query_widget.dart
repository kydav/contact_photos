import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;

const _googleCseApiKey = String.fromEnvironment('GOOGLE_CSE_API_KEY');
const _googleCseCx = String.fromEnvironment('GOOGLE_CSE_CX');

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
      if (_googleCseApiKey.isEmpty || _googleCseCx.isEmpty) {
        errorText.value =
            'Missing Google CSE config. Run with --dart-define=GOOGLE_CSE_API_KEY=... --dart-define=GOOGLE_CSE_CX=...';
        imageOptions.value = [];
        return;
      }

      isLoading.value = true;
      errorText.value = null;
      imageOptions.value = [];

      try {
        final urls = await _queryImageUrlsFromCustomSearch(
          companyName: companyName,
          websiteUrl: companyWebsiteUrl,
        );
        imageOptions.value = await _loadRenderableImageOptions(urls);
        if (imageOptions.value.isEmpty) {
          errorText.value = 'No renderable company images were found.';
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

Future<List<String>> _queryImageUrlsFromCustomSearch({
  required String companyName,
  required String websiteUrl,
}) async {
  final urls = <String>{};
  final websiteHost = _extractHost(websiteUrl);
  final queries = <String>[
    '"$companyName" official logo',
    '"$companyName" brand logo',
    if (websiteHost != null && websiteHost.isNotEmpty)
      'site:$websiteHost "$companyName" logo',
  ];

  for (final query in queries) {
    final queryResults = await _queryCustomSearchForImages(query);
    urls.addAll(queryResults);
    if (urls.length >= 12) {
      break;
    }
  }

  if (urls.isEmpty) {
    throw Exception('No image URLs returned by Google Custom Search.');
  }
  return urls.take(12).toList();
}

Future<List<String>> _queryCustomSearchForImages(String query) async {
  final uri = Uri.https('www.googleapis.com', '/customsearch/v1', {
    'key': _googleCseApiKey,
    'cx': _googleCseCx,
    'q': query,
    'searchType': 'image',
    'num': '10',
    'safe': 'active',
    'imgType': 'photo',
  });

  final response = await http.get(
    uri,
    headers: const {
      'User-Agent': 'ContactPhotos/1.0',
      'Accept': 'application/json',
    },
  ).timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    final preview = response.body.length > 180
        ? '${response.body.substring(0, 180)}...'
        : response.body;
    throw Exception('Google CSE error ${response.statusCode}: $preview');
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    return [];
  }

  final items = decoded['items'];
  if (items is! List) {
    return [];
  }

  final urls = <String>{};
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    final rawLink = (item['link'] as String?)?.trim();
    if (rawLink == null || rawLink.isEmpty) continue;
    final linkUri = Uri.tryParse(rawLink);
    if (linkUri == null || linkUri.host.isEmpty) continue;
    if (linkUri.scheme != 'https' && linkUri.scheme != 'http') continue;
    if (_isLikelySvgUrl(linkUri.toString())) continue;

    final mime = (item['mime'] as String?)?.toLowerCase();
    if (mime != null && mime.contains('svg')) continue;

    urls.add(linkUri.toString());
    if (urls.length >= 10) break;
  }
  return urls.toList();
}

String? _extractHost(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  return host.startsWith('www.') ? host.substring(4) : host;
}

Future<List<CompanyImageOption>> _loadRenderableImageOptions(
  List<String> urls,
) async {
  final results = <CompanyImageOption>[];
  final seenUrls = <String>{};

  for (final url in urls) {
    if (!seenUrls.add(url)) continue;
    final bytes = await _downloadImageBytes(url);
    if (bytes == null) continue;
    results.add(CompanyImageOption(url: url, bytes: bytes));
    if (results.length >= 8) break;
  }

  return results;
}

Future<Uint8List?> _downloadImageBytes(String imageUrl) async {
  try {
    final response = await http.get(
      Uri.parse(imageUrl),
      headers: const {'User-Agent': 'Mozilla/5.0'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('svg')) {
      return null;
    }
    if (!contentType.startsWith('image/') &&
        !_looksLikeImageBytes(response.bodyBytes)) {
      return null;
    }
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}

bool _isLikelySvgUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.svg') || lower.contains('format=svg');
}

bool _looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length < 12) {
    return false;
  }

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

  return isPng || isJpeg || isGif || isWebp;
}
