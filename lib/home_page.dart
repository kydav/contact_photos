import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class SenderCandidate {
  const SenderCandidate({
    required this.sender,
    required this.messageCount,
  });

  final String sender;
  final int messageCount;
}

class LogoCandidate {
  const LogoCandidate({
    required this.sourceUrl,
    required this.bytes,
  });

  final String sourceUrl;
  final Uint8List bytes;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SmsQuery _smsQuery = SmsQuery();
  final TextEditingController _companyNameController = TextEditingController();

  List<SenderCandidate> _senderCandidates = [];
  List<LogoCandidate> _logoCandidates = [];

  String? _selectedSender;
  int? _selectedLogoIndex;
  String? _scanStatus;

  bool _isScanning = false;
  bool _isGeneratingImages = false;
  bool _isCreatingContact = false;

  bool get _canCreateContact {
    return _selectedSender != null &&
        _selectedLogoIndex != null &&
        _companyNameController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _scanMessageSenders() async {
    setState(() {
      _isScanning = true;
      _scanStatus = null;
    });

    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        setState(() {
          _senderCandidates = [];
          _selectedSender = null;
          _scanStatus =
              'Message scanning is currently available on Android only.';
        });
        return;
      }

      final smsPermission = await Permission.sms.request();
      if (!smsPermission.isGranted) {
        setState(() {
          _scanStatus =
              'SMS permission is required to scan message senders on Android.';
        });
        return;
      }

      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 500,
      );

      final senderCounts = <String, int>{};
      for (final message in messages) {
        final sender = message.sender?.trim() ?? '';
        if (sender.isEmpty) continue;
        senderCounts[sender] = (senderCounts[sender] ?? 0) + 1;
      }

      final candidates = senderCounts.entries
          .map(
            (entry) => SenderCandidate(
              sender: entry.key,
              messageCount: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.messageCount.compareTo(a.messageCount));

      setState(() {
        _senderCandidates = candidates;
        _selectedSender =
            candidates.isNotEmpty ? candidates.first.sender : null;
        _scanStatus = candidates.isEmpty
            ? 'No message senders were found.'
            : 'Found ${candidates.length} senders.';
      });
    } catch (error) {
      setState(() {
        _scanStatus = 'Could not scan message senders: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _generateLogoOptions() async {
    final companyName = _companyNameController.text.trim();
    if (companyName.isEmpty) {
      _showMessage('Enter a company name before generating image options.');
      return;
    }

    setState(() {
      _isGeneratingImages = true;
      _logoCandidates = [];
      _selectedLogoIndex = null;
    });

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        tools: [Tool.googleSearch()],
      );

      final response = await model.generateContent([
        Content.text('''
          Return JSON only in this format:
          {"imageUrls":["https://..."],"pageUrls":["https://..."]}

          Task:
          - Use Google Search grounding and only return URLs from real search results.
          - Find up to 6 publicly accessible direct image URLs (PNG/JPG/WEBP/SVG) that could represent the official logo or branding of "$companyName".
          - Include 3-6 source page URLs in pageUrls where the logos were found.
          - Prefer direct image files over web pages.
          - Do not include markdown.
          '''),
      ]);

      final parsedUrls = _extractLogoUrlsFromResponse(response.text);
      final pageUrlsFromResponse = _extractPageUrlsFromResponse(response.text);
      final groundedPageUrls = _extractGroundedPageUrls(response);
      final responseDomains = _extractDomainsFromResponse(response.text);
      final domainImageUrls = _buildDomainImageUrls(
        pageUrls: [...pageUrlsFromResponse, ...groundedPageUrls],
        domains: responseDomains,
      );
      final discoveredPageImageUrls = await _discoverLogoImageUrlsFromPages(
        _dedupeUrls([...pageUrlsFromResponse, ...groundedPageUrls]),
      );
      final aiCandidates = await _loadRenderableLogoCandidates(
        _dedupeUrls(
            [...parsedUrls, ...discoveredPageImageUrls, ...domainImageUrls]),
      );
      final fallbackCandidates = await _loadRenderableLogoCandidates(
        _fallbackLogoUrls(companyName),
      );
      final finalCandidates =
          aiCandidates.isNotEmpty ? aiCandidates : fallbackCandidates;

      if (finalCandidates.isEmpty) {
        throw Exception('No renderable image candidates were found.');
      }

      setState(() {
        _logoCandidates = finalCandidates;
        _selectedLogoIndex = 0;
      });

      if (aiCandidates.isEmpty) {
        _showMessage(
          'Could not find renderable web logos; showing fallback options.',
        );
      }
    } catch (error) {
      _showMessage('Could not generate image options: $error');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingImages = false);
      }
    }
  }

  Future<List<LogoCandidate>> _loadRenderableLogoCandidates(
    List<String> urls,
  ) async {
    final candidates = <LogoCandidate>[];
    final seenUrls = <String>{};

    for (final url in urls) {
      if (!seenUrls.add(url)) continue;
      final bytes = await _downloadImageBytesIfRenderable(url);
      if (bytes != null) {
        candidates.add(LogoCandidate(sourceUrl: url, bytes: bytes));
      }
      if (candidates.length >= 6) {
        break;
      }
    }

    return candidates;
  }

  List<String> _dedupeUrls(Iterable<String> rawUrls) {
    final uniqueUrls = <String>{};
    for (final rawUrl in rawUrls) {
      final cleanedUrl = _trimTrailingUrlPunctuation(rawUrl).trim();
      if (_isValidHttpUrl(cleanedUrl)) {
        uniqueUrls.add(cleanedUrl);
      }
    }
    return uniqueUrls.toList();
  }

  List<String> _extractGroundedPageUrls(GenerateContentResponse response) {
    final groundedUrls = <String>{};

    for (final candidate in response.candidates) {
      for (final chunk in candidate.groundingMetadata?.groundingChunks ?? []) {
        final url = chunk.web?.uri;
        if (url != null && _isValidHttpUrl(url)) {
          groundedUrls.add(url);
        }
      }
      for (final citation in candidate.citationMetadata?.citations ?? []) {
        final url = citation.uri?.toString();
        if (url != null && _isValidHttpUrl(url)) {
          groundedUrls.add(url);
        }
      }
    }

    return groundedUrls.toList();
  }

  Future<List<String>> _discoverLogoImageUrlsFromPages(
    List<String> pageUrls,
  ) async {
    final discoveredUrls = <String>{};

    for (final pageUrl in pageUrls.take(8)) {
      try {
        final response = await http
            .get(
              Uri.parse(pageUrl),
              headers: _webRequestHeaders,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          continue;
        }

        final contentType =
            response.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.startsWith('image/') ||
            _looksLikeImageBytes(response.bodyBytes)) {
          discoveredUrls.add(pageUrl);
          continue;
        }

        if (contentType.contains('text/html') || contentType.isEmpty) {
          discoveredUrls.addAll(
              _extractLogoImageUrlsFromHtml(response.body, Uri.parse(pageUrl)));
        }
      } catch (error) {
        debugPrint('Page crawl failed for $pageUrl: $error');
      }
    }

    return discoveredUrls.take(24).toList();
  }

  List<String> _extractLogoUrlsFromResponse(String? responseText) {
    if (responseText == null || responseText.trim().isEmpty) {
      return [];
    }

    final candidateUrls = <String>[
      ..._extractStringListForJsonKey(responseText, 'imageUrls'),
    ];

    final regexUrls = _extractHttpUrls(responseText);
    candidateUrls.addAll(regexUrls);

    final dedupedUrls = <String>{};
    for (final rawUrl in candidateUrls) {
      final cleanedUrl = _trimTrailingUrlPunctuation(rawUrl, removeDot: true);
      if (_isValidHttpUrl(cleanedUrl)) {
        dedupedUrls.add(cleanedUrl);
      }
    }

    return dedupedUrls.take(6).toList();
  }

  List<String> _extractPageUrlsFromResponse(String? responseText) {
    if (responseText == null || responseText.trim().isEmpty) {
      return [];
    }
    return _dedupeUrls(_extractStringListForJsonKey(responseText, 'pageUrls'));
  }

  List<String> _extractStringListForJsonKey(
    String responseText,
    String key,
  ) {
    final jsonPayload = _extractJsonPayload(responseText);
    if (jsonPayload == null) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonPayload);
      if (decoded is Map) {
        final value = decoded[key];
        if (value is List) {
          return value.whereType<String>().toList();
        }
      } else if (decoded is List && key == 'imageUrls') {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Ignore invalid payload.
    }

    return [];
  }

  List<String> _extractDomainsFromResponse(String? responseText) {
    if (responseText == null || responseText.trim().isEmpty) {
      return [];
    }

    final domains = <String>{
      ..._extractStringListForJsonKey(responseText, 'domains'),
    };

    final domainRegex = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)([a-z0-9.-]+\.[a-z]{2,})(?:[\/\s]|$)',
      caseSensitive: false,
    );
    for (final match in domainRegex.allMatches(responseText)) {
      final domain = match.group(1);
      if (domain != null) {
        final normalized = _normalizeDomain(domain);
        if (normalized != null) {
          domains.add(normalized);
        }
      }
    }

    return domains.toList();
  }

  List<String> _buildDomainImageUrls({
    required List<String> pageUrls,
    required List<String> domains,
  }) {
    final normalizedDomains = <String>{};

    for (final domain in domains) {
      final normalized = _normalizeDomain(domain);
      if (normalized != null) {
        normalizedDomains.add(normalized);
      }
    }

    for (final pageUrl in pageUrls) {
      final uri = Uri.tryParse(pageUrl);
      final host = uri?.host;
      if (host == null || host.isEmpty) continue;
      final normalized = _normalizeDomain(host);
      if (normalized != null) {
        normalizedDomains.add(normalized);
      }
    }

    final urls = <String>{};
    for (final domain in normalizedDomains.take(12)) {
      urls.add(
        'https://www.google.com/s2/favicons?sz=256&domain_url=https://$domain',
      );
      urls.add(
        'https://www.google.com/s2/favicons?sz=128&domain_url=https://$domain',
      );
      urls.add('https://$domain/favicon.ico');
      if (!domain.startsWith('www.')) {
        urls.add('https://www.$domain/favicon.ico');
      }
    }

    return urls.toList();
  }

  String? _normalizeDomain(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    normalized = normalized.replaceFirst(RegExp(r'^https?://'), '');
    normalized = normalized.split('/').first;
    normalized = normalized.split(':').first;
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
    }
    if (!normalized.contains('.') || normalized.contains(' ')) {
      return null;
    }
    return normalized;
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

    final arrayStart = trimmed.indexOf('[');
    final arrayEnd = trimmed.lastIndexOf(']');
    if (arrayStart >= 0 && arrayEnd > arrayStart) {
      return trimmed.substring(arrayStart, arrayEnd + 1);
    }
    return null;
  }

  List<String> _fallbackLogoUrls(String companyName) {
    final encodedName = Uri.encodeComponent(companyName);
    return [
      'https://ui-avatars.com/api/?name=$encodedName&background=1E3A8A&color=ffffff&size=256&bold=true',
      'https://ui-avatars.com/api/?name=$encodedName&background=065F46&color=ffffff&size=256&bold=true',
      'https://ui-avatars.com/api/?name=$encodedName&background=9D174D&color=ffffff&size=256&bold=true',
      'https://ui-avatars.com/api/?name=$encodedName&background=0F172A&color=ffffff&size=256&bold=true',
    ];
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _looksLikeImageUrl(String url) {
    final lower = url.toLowerCase();

    final uri = Uri.tryParse(lower);
    final path = uri?.path.toLowerCase() ?? lower;
    const imageExtensions = [
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.gif',
      '.svg',
      '.bmp',
      '.ico',
    ];

    if (imageExtensions.any(path.endsWith)) {
      return true;
    }

    return lower.contains('logo') ||
        lower.contains('icon') ||
        lower.contains('favicon') ||
        lower.contains('/s2/favicons');
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

  Map<String, String> get _webRequestHeaders => const {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      };

  Future<Uint8List?> _downloadImageBytesIfRenderable(
    String imageUrl, {
    int depth = 0,
  }) async {
    if (depth > 2) {
      return null;
    }

    try {
      final uri = Uri.parse(imageUrl);
      final response = await http
          .get(uri, headers: _webRequestHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.contains('image/svg')) {
        return null;
      }
      if (contentType.startsWith('image/') ||
          _looksLikeImageBytes(response.bodyBytes)) {
        return response.bodyBytes;
      }

      if (contentType.contains('text/html') || contentType.isEmpty) {
        final htmlBody = response.body;
        final extractedUrls = _extractLogoImageUrlsFromHtml(htmlBody, uri);
        for (final extractedUrl in extractedUrls) {
          if (extractedUrl == imageUrl) continue;
          final bytes = await _downloadImageBytesIfRenderable(
            extractedUrl,
            depth: depth + 1,
          );
          if (bytes != null) {
            return bytes;
          }
        }
      }
      return null;
    } catch (error) {
      debugPrint('Image candidate failed for $imageUrl: $error');
      return null;
    }
  }

  List<String> _extractLogoImageUrlsFromHtml(String html, Uri baseUri) {
    final extractedUrls = <String>{};

    void addCandidate(String? rawValue, {bool requireLogoLike = true}) {
      if (rawValue == null || rawValue.trim().isEmpty) return;
      final decoded = rawValue.replaceAll('&amp;', '&').trim();
      final absolute = baseUri.resolve(decoded).toString();
      if (_isValidHttpUrl(absolute) &&
          (!requireLogoLike || _looksLikeImageUrl(absolute))) {
        extractedUrls.add(absolute);
      }
    }

    for (final tag in _extractHtmlStartTags(html, 'meta')) {
      final property = _extractHtmlAttribute(tag, 'property')?.toLowerCase();
      final name = _extractHtmlAttribute(tag, 'name')?.toLowerCase();

      final isLogoMeta = property == 'og:image' || name == 'twitter:image';
      if (!isLogoMeta) continue;

      addCandidate(
        _extractHtmlAttribute(tag, 'content'),
        requireLogoLike: false,
      );
    }

    for (final tag in _extractHtmlStartTags(html, 'link')) {
      final rel = _extractHtmlAttribute(tag, 'rel')?.toLowerCase() ?? '';
      if (!rel.contains('icon')) continue;
      addCandidate(
        _extractHtmlAttribute(tag, 'href'),
        requireLogoLike: false,
      );
    }

    for (final tag in _extractHtmlStartTags(html, 'img')) {
      final loweredTag = tag.toLowerCase();
      if (!loweredTag.contains('logo') &&
          !loweredTag.contains('brand') &&
          !loweredTag.contains('icon')) {
        continue;
      }
      addCandidate(_extractHtmlAttribute(tag, 'src'));
    }

    return extractedUrls.take(12).toList();
  }

  Future<void> _createContact() async {
    final sender = _selectedSender;
    final selectedLogoIndex = _selectedLogoIndex;
    final companyName = _companyNameController.text.trim();

    final logoBytes = selectedLogoIndex != null &&
            selectedLogoIndex >= 0 &&
            selectedLogoIndex < _logoCandidates.length
        ? _logoCandidates[selectedLogoIndex].bytes
        : null;

    if (sender == null || logoBytes == null || companyName.isEmpty) {
      _showMessage('Select a sender, enter company name, and select an image.');
      return;
    }

    setState(() => _isCreatingContact = true);

    try {
      final hasPermission =
          await FlutterContacts.requestPermission(readonly: false);
      if (!hasPermission) {
        _showMessage('Contacts permission is required to create contacts.');
        return;
      }

      final existingContact = await _findExistingContact(sender);
      final isNewContact = existingContact == null;

      if (existingContact == null) {
        final contact = Contact(
          name: Name(first: companyName),
          phones: [Phone(sender)],
          photo: logoBytes,
        );
        await contact.insert();
      } else {
        existingContact.name = Name(first: companyName);
        existingContact.photo = logoBytes;
        final hasSender = existingContact.phones
            .any((phone) => _senderMatches(phone.number, sender));
        if (!hasSender) {
          existingContact.phones.add(Phone(sender));
        }
        await existingContact.update();
      }

      _showMessage(
        isNewContact
            ? '$companyName contact created.'
            : '$companyName updated.',
      );
    } catch (error) {
      _showMessage('Could not create contact: $error');
    } finally {
      if (mounted) {
        setState(() => _isCreatingContact = false);
      }
    }
  }

  Future<Contact?> _findExistingContact(String sender) async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    for (final contact in contacts) {
      final matches = contact.phones.any(
        (phone) => _senderMatches(phone.number, sender),
      );
      if (matches) return contact;
    }
    return null;
  }

  bool _senderMatches(String left, String right) {
    final normalizedLeft = _normalizePhoneNumber(left);
    final normalizedRight = _normalizePhoneNumber(right);

    if (normalizedLeft.isNotEmpty && normalizedRight.isNotEmpty) {
      return normalizedLeft == normalizedRight;
    }

    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }

  String _normalizePhoneNumber(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      if (codeUnit >= 48 && codeUnit <= 57) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  Iterable<String> _extractHttpUrls(String text) sync* {
    var index = 0;
    while (index < text.length) {
      final httpIndex = text.indexOf('http://', index);
      final httpsIndex = text.indexOf('https://', index);

      var start = -1;
      if (httpIndex == -1) {
        start = httpsIndex;
      } else if (httpsIndex == -1) {
        start = httpIndex;
      } else {
        start = httpIndex < httpsIndex ? httpIndex : httpsIndex;
      }

      if (start == -1) {
        return;
      }

      var end = start;
      while (end < text.length) {
        final char = text[end];
        if (char == ' ' ||
            char == '\n' ||
            char == '\r' ||
            char == '\t' ||
            char == '"' ||
            char == '\'' ||
            char == '<' ||
            char == '>') {
          break;
        }
        end++;
      }

      yield text.substring(start, end);
      index = end;
    }
  }

  String _trimTrailingUrlPunctuation(String value, {bool removeDot = false}) {
    var end = value.length;
    while (end > 0) {
      final char = value[end - 1];
      final isTrimChar = char == ')' ||
          char == ',' ||
          char == ']' ||
          (removeDot && char == '.');
      if (!isTrimChar) {
        break;
      }
      end--;
    }
    return value.substring(0, end);
  }

  List<String> _extractHtmlStartTags(String html, String tagName) {
    final tags = <String>[];
    final lowerHtml = html.toLowerCase();
    final needle = '<$tagName';
    var searchFrom = 0;

    while (true) {
      final start = lowerHtml.indexOf(needle, searchFrom);
      if (start == -1) {
        break;
      }

      final end = html.indexOf('>', start);
      if (end == -1) {
        break;
      }

      tags.add(html.substring(start, end + 1));
      searchFrom = end + 1;
    }

    return tags;
  }

  String? _extractHtmlAttribute(String tag, String attributeName) {
    final lowerTag = tag.toLowerCase();
    final lowerAttribute = attributeName.toLowerCase();
    var searchFrom = 0;

    while (true) {
      final attrIndex = lowerTag.indexOf(lowerAttribute, searchFrom);
      if (attrIndex == -1) {
        return null;
      }

      final beforeIndex = attrIndex - 1;
      if (beforeIndex >= 0) {
        final beforeChar = lowerTag[beforeIndex];
        final isBoundary = beforeChar == ' ' ||
            beforeChar == '\n' ||
            beforeChar == '\t' ||
            beforeChar == '<';
        if (!isBoundary) {
          searchFrom = attrIndex + 1;
          continue;
        }
      }

      var equalsIndex = attrIndex + lowerAttribute.length;
      while (equalsIndex < tag.length && tag[equalsIndex].trim().isEmpty) {
        equalsIndex++;
      }

      if (equalsIndex >= tag.length || tag[equalsIndex] != '=') {
        searchFrom = attrIndex + 1;
        continue;
      }

      equalsIndex++;
      while (equalsIndex < tag.length && tag[equalsIndex].trim().isEmpty) {
        equalsIndex++;
      }

      if (equalsIndex >= tag.length) {
        return null;
      }

      final quote = tag[equalsIndex];
      if (quote == '"' || quote == '\'') {
        final valueStart = equalsIndex + 1;
        final valueEnd = tag.indexOf(quote, valueStart);
        if (valueEnd == -1) {
          return null;
        }
        return tag.substring(valueStart, valueEnd);
      }

      final valueStart = equalsIndex;
      var valueEnd = valueStart;
      while (valueEnd < tag.length) {
        final char = tag[valueEnd];
        if (char == ' ' || char == '\n' || char == '\t' || char == '>') {
          break;
        }
        valueEnd++;
      }
      return tag.substring(valueStart, valueEnd);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Company Contact')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 1: Scan message senders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _isScanning ? null : _scanMessageSenders,
            icon: const Icon(Icons.sms),
            label: const Text('Scan senders'),
          ),
          if (_isScanning) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_scanStatus != null) ...[
            const SizedBox(height: 8),
            Text(_scanStatus!),
          ],
          if (_senderCandidates.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSender,
              decoration: const InputDecoration(
                labelText: 'Message sender',
                border: OutlineInputBorder(),
              ),
              items: _senderCandidates
                  .map(
                    (candidate) => DropdownMenuItem(
                      value: candidate.sender,
                      child: Text(
                        '${candidate.sender} (${candidate.messageCount} msgs)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedSender = value),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Step 2: Enter company name',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text(
            'Step 3: Generate image options',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _isGeneratingImages ? null : _generateLogoOptions,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate image options'),
          ),
          if (_isGeneratingImages) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_logoCandidates.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _logoCandidates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final logoCandidate = _logoCandidates[index];
                  final isSelected = index == _selectedLogoIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLogoIndex = index),
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  logoCandidate.bytes,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Option ${index + 1}',
                              style: const TextStyle(fontSize: 12),
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
          const SizedBox(height: 24),
          const Text(
            'Step 4: Create contact',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _canCreateContact && !_isCreatingContact
                ? _createContact
                : null,
            icon: _isCreatingContact
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add),
            label: const Text('Create contact'),
          ),
        ],
      ),
    );
  }
}
