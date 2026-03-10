import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
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
        final urls = await _queryImageUrlsFromGemini(
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

Future<List<String>> _queryImageUrlsFromGemini({
  required String companyName,
  required String websiteUrl,
}) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    generationConfig: GenerationConfig(responseMimeType: 'application/json'),
  );

  final response = await model.generateContent([
    Content.text('''
Return JSON only in this format:
{
  "imageUrls": [
    "https://example.com/logo.png"
  ]
}

Task:
- Find up to 8 likely logo or branding image URLs for "$companyName".
- Use "$websiteUrl" as the primary website reference when selecting candidates.
- Prefer direct image URLs.
'''),
  ]);

  final parsedUrls = _extractImageUrls(response.text);
  if (parsedUrls.isEmpty) {
    throw Exception('No image URLs returned by AI.');
  }
  return parsedUrls;
}

List<String> _extractImageUrls(String? responseText) {
  if (responseText == null || responseText.trim().isEmpty) {
    return [];
  }

  final jsonPayload = _extractJsonPayload(responseText);
  if (jsonPayload == null) {
    return [];
  }

  try {
    final decoded = jsonDecode(jsonPayload);
    final values = decoded is Map<String, dynamic>
        ? decoded['imageUrls']
        : decoded is List
            ? decoded
            : null;
    if (values is! List) return [];

    final urls = <String>{};
    for (final value in values) {
      final rawUrl = (value as String?)?.trim();
      if (rawUrl == null || rawUrl.isEmpty) continue;
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.host.isEmpty) continue;
      if (uri.scheme != 'https' && uri.scheme != 'http') continue;
      urls.add(uri.toString());
      if (urls.length >= 8) break;
    }
    return urls.toList();
  } catch (_) {
    return [];
  }
}

String? _extractJsonPayload(String responseText) {
  final trimmed = responseText.trim();
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
    if (!contentType.startsWith('image/')) {
      return null;
    }
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}
