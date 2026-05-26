import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:contact_photos/extensions/http_extensions.dart';
import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/extensions/uri_extensions.dart';
import 'package:contact_photos/helpers/app_secrets.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LocalLogoReasoner {
  static LlamaParent? _llama;
  static Future<LlamaParent>? _loadingLlama;

  static bool get isConfigured => AppSecrets.hasLocalLlamaLogoFallback;

  static Future<List<String>> suggestLogoUrls({
    required String companyName,
    required String companyWebsiteUrl,
    Iterable<String> existingUrls = const [],
  }) async {
    if (!isConfigured) {
      return [];
    }

    try {
      final baseUri = companyWebsiteUrl.normalizeWebsiteUri();
      if (baseUri == null) {
        return [];
      }

      final pageSummary = await _buildPageSummary(baseUri);
      if (pageSummary.trim().isEmpty) {
        return [];
      }

      final existingUrlSet = existingUrls.toSet();
      final response = await _generate(_buildPrompt(
        companyName: companyName,
        companyWebsiteUrl: companyWebsiteUrl,
        existingUrls: existingUrlSet,
        pageSummary: pageSummary,
      ));

      final urls = _parseCandidateUrls(response, baseUri)
          .where((url) => !existingUrlSet.contains(url))
          .toList();

      developer.log(
        'Local Llama suggested ${urls.length} logo candidate(s).',
        name: 'LocalLogoReasoner',
      );
      return urls;
    } catch (error) {
      developer.log(
        'Local Llama logo fallback skipped: $error',
        name: 'LocalLogoReasoner',
      );
      return [];
    }
  }

  static Future<String> _buildPageSummary(Uri baseUri) async {
    final buffer = StringBuffer();
    final websiteUris = baseUri.buildWebsiteCandidates().take(2);

    for (final websiteUri in websiteUris) {
      final response = await websiteUri.tryGet();
      if (response == null ||
          response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !response.looksLikeHtml()) {
        continue;
      }

      final html = response.body;
      buffer.writeln('Page: $websiteUri');
      final title = _extractTitle(html);
      if (title != null) {
        buffer.writeln('Title: $title');
      }

      _writeTags(buffer, 'meta', html.extractHtmlStartTags('meta'), limit: 16);
      _writeTags(buffer, 'link', html.extractHtmlStartTags('link'), limit: 16);
      _writeTags(buffer, 'img', html.extractHtmlStartTags('img'), limit: 36);
      _writeTags(buffer, 'a', _socialAnchorTags(html), limit: 16);
      buffer.writeln();
    }

    final result = buffer.toString();
    const maxChars = 14000;
    if (result.length <= maxChars) {
      return result;
    }
    return result.substring(0, maxChars);
  }

  static String? _extractTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)<\/title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final title = match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title == null || title.isEmpty) {
      return null;
    }
    return title;
  }

  static List<String> _socialAnchorTags(String html) {
    return html.extractHtmlStartTags('a').where((tag) {
      final lower = tag.toLowerCase();
      return lower.contains('facebook') ||
          lower.contains('instagram') ||
          lower.contains('linkedin') ||
          lower.contains('twitter') ||
          lower.contains('x.com');
    }).toList();
  }

  static void _writeTags(
    StringBuffer buffer,
    String label,
    List<String> tags, {
    required int limit,
  }) {
    final compactTags = tags
        .map((tag) => tag.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((tag) => tag.isNotEmpty)
        .take(limit);

    for (final tag in compactTags) {
      buffer.writeln('$label: ${_truncate(tag, 420)}');
    }
  }

  static String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }

  static String _buildPrompt({
    required String companyName,
    required String companyWebsiteUrl,
    required Set<String> existingUrls,
    required String pageSummary,
  }) {
    return '''
You identify official company logo and app/contact icon image URLs from compact website markup.

Return JSON only in this format:
{
  "candidates": [
    {"url": "https://example.com/logo.png", "confidence": 0.82, "reason": "header logo"}
  ]
}

Rules:
- Use only URLs present in the page summary or obvious absolute URLs resolved from present relative paths.
- Prefer official logo, brand mark, apple-touch-icon, favicon, android-chrome, og:image, or header logo assets.
- Avoid social network platform logos, sprites, placeholders, share buttons, tracking pixels, and generic UI icons.
- Do not repeat existing URLs.
- Return at most 8 candidates.
- Use absolute http or https URLs.

Company: $companyName
Website: $companyWebsiteUrl

Existing URLs:
${existingUrls.take(20).join('\n')}

Page summary:
$pageSummary
''';
  }

  static Future<String> _generate(String plainPrompt) async {
    final llama = await _getLlama();
    final prompt = _formatPrompt(plainPrompt);
    final chunks = <String>[];

    late final StreamSubscription<String> streamSubscription;
    streamSubscription = llama.stream.listen(chunks.add);

    try {
      final promptId = await llama.sendPrompt(prompt);
      await llama.waitForCompletion(promptId).timeout(
            const Duration(seconds: 45),
          );
      return chunks.join();
    } finally {
      await streamSubscription.cancel();
    }
  }

  static String _formatPrompt(String plainPrompt) {
    final history = ChatHistory()
      ..addMessage(role: Role.user, content: plainPrompt)
      ..addMessage(role: Role.assistant, content: '');

    return history.exportFormat(
      _chatFormat,
      leaveLastAssistantOpen: true,
    );
  }

  static ChatFormat get _chatFormat {
    switch (AppSecrets.llamaChatFormat.toLowerCase()) {
      case 'alpaca':
        return ChatFormat.alpaca;
      case 'chatml':
        return ChatFormat.chatml;
      case 'harmony':
        return ChatFormat.harmony;
      case 'qwen3':
        return ChatFormat.qwen3;
      case 'gemma':
      default:
        return ChatFormat.gemma;
    }
  }

  static Future<LlamaParent> _getLlama() {
    final ready = _llama;
    if (ready != null) {
      return Future.value(ready);
    }
    final loading = _loadingLlama;
    if (loading != null) {
      return loading;
    }

    final future = _loadLlama();
    _loadingLlama = future;
    return future;
  }

  static Future<LlamaParent> _loadLlama() async {
    if (AppSecrets.llamaLibraryPath.isNotEmpty) {
      Llama.libraryPath = AppSecrets.llamaLibraryPath;
    }

    final modelParams = ModelParams()..nGpuLayers = AppSecrets.llamaGpuLayers;

    final contextParams = ContextParams()
      ..nCtx = AppSecrets.llamaContextTokens
      ..nPredict = AppSecrets.llamaPredictTokens
      ..nThreads = AppSecrets.llamaThreads
      ..nThreadsBatch = AppSecrets.llamaThreads;

    final samplerParams = SamplerParams()
      ..greedy = true
      ..temp = 0.0
      ..topK = 20
      ..topP = 0.8
      ..penaltyRepeat = 1.05;

    final llama = LlamaParent(
      LlamaLoad(
        path: AppSecrets.llamaModelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplerParams,
      ),
    );

    await llama.init();
    _llama = llama;
    _loadingLlama = null;
    return llama;
  }

  static List<String> _parseCandidateUrls(String response, Uri baseUri) {
    final jsonPayload = response.extractJsonPayload();
    if (jsonPayload == null) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonPayload);
      final items = decoded is Map<String, dynamic>
          ? decoded['candidates']
          : decoded is List
              ? decoded
              : null;
      if (items is! List) {
        return [];
      }

      final urls = <String>{};
      for (final item in items) {
        final raw = item is Map ? item['url'] : item;
        if (raw is! String || raw.trim().isEmpty) {
          continue;
        }

        final resolved = baseUri.resolve(raw.trim());
        if (resolved.scheme != 'http' && resolved.scheme != 'https') {
          continue;
        }
        if (resolved.host.isEmpty) {
          continue;
        }
        urls.add(resolved.toString());
        if (urls.length >= 8) {
          break;
        }
      }
      return urls.toList();
    } catch (_) {
      return [];
    }
  }
}
