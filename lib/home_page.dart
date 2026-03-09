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
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );

      final response = await model.generateContent([
        Content.text('''
Return JSON only in this format:
{"imageUrls":["https://...","https://...","https://...","https://..."]}

Task:
- Find up to 6 publicly accessible direct image URLs (PNG/JPG/WEBP) that could represent the official logo or branding of "$companyName".
- Prefer direct image files over web pages.
- Do not include markdown.
'''),
      ]);

      final parsedUrls = _extractLogoUrlsFromResponse(response.text);
      final aiCandidates = await _loadRenderableLogoCandidates(parsedUrls);
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

  List<String> _extractLogoUrlsFromResponse(String? responseText) {
    if (responseText == null || responseText.trim().isEmpty) {
      return [];
    }

    final candidateUrls = <String>[];

    final jsonPayload = _extractJsonPayload(responseText);
    if (jsonPayload != null) {
      try {
        final decoded = jsonDecode(jsonPayload);
        if (decoded is Map) {
          final imageUrls = decoded['imageUrls'];
          if (imageUrls is List) {
            candidateUrls.addAll(imageUrls.whereType<String>());
          }
        } else if (decoded is List) {
          candidateUrls.addAll(decoded.whereType<String>());
        }
      } catch (_) {
        // Fall back to regex extraction below.
      }
    }

    final regexUrls = RegExp('https?://[^\\s"\\\'<>]+')
        .allMatches(responseText)
        .map((match) => match.group(0))
        .whereType<String>();
    candidateUrls.addAll(regexUrls);

    final dedupedUrls = <String>{};
    for (final rawUrl in candidateUrls) {
      final cleanedUrl = rawUrl.replaceAll(RegExp(r'[),.\]]+$'), '');
      if (_isValidHttpUrl(cleanedUrl)) {
        dedupedUrls.add(cleanedUrl);
      }
    }

    return dedupedUrls.take(6).toList();
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

  Future<Uint8List?> _downloadImageBytesIfRenderable(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'ContactPhotos/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.startsWith('image/')) {
        return response.bodyBytes;
      }

      if (contentType.contains('text/html')) {
        final htmlBody = response.body;
        final extracted = _extractImageUrlFromHtml(htmlBody, uri);
        if (extracted != null && extracted != imageUrl) {
          return _downloadImageBytesIfRenderable(extracted);
        }
      }
      return null;
    } catch (error) {
      debugPrint('Image candidate failed for $imageUrl: $error');
      return null;
    }
  }

  String? _extractImageUrlFromHtml(String html, Uri baseUri) {
    final ogImageRegex = RegExp(
      "<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']",
      caseSensitive: false,
    );
    final twitterImageRegex = RegExp(
      "<meta[^>]+name=[\"']twitter:image[\"'][^>]+content=[\"']([^\"']+)[\"']",
      caseSensitive: false,
    );

    final match =
        ogImageRegex.firstMatch(html) ?? twitterImageRegex.firstMatch(html);
    if (match == null) return null;

    final rawValue = match.group(1);
    if (rawValue == null || rawValue.trim().isEmpty) return null;
    final decoded = rawValue.replaceAll('&amp;', '&').trim();
    return baseUri.resolve(decoded).toString();
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
    return value.replaceAll(RegExp(r'[^0-9]'), '');
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
