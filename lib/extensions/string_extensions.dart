import 'dart:convert';

import 'package:contact_photos/models/company_search_result.dart';

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
}
