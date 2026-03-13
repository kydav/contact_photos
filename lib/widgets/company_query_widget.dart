import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CompanySearchResult {
  const CompanySearchResult({
    required this.name,
    required this.websiteUrl,
  });

  final String name;
  final String websiteUrl;
}

typedef CompanySelectedCallback = void Function(CompanySearchResult company);

class CompanyQueryWidget extends HookWidget {
  const CompanyQueryWidget({
    super.key,
    required this.onCompanySelected,
  });

  final CompanySelectedCallback onCompanySelected;

  @override
  Widget build(BuildContext context) {
    final queryController = useTextEditingController();
    final isLoading = useState(false);
    final hasSearched = useState(false);
    final errorText = useState<String?>(null);
    final companies = useState<List<CompanySearchResult>>([]);

    Future<void> searchCompanies() async {
      final query = queryController.text.trim();
      if (query.isEmpty) {
        errorText.value = 'Enter a company name to search.';
        companies.value = [];
        return;
      }

      isLoading.value = true;
      hasSearched.value = true;
      errorText.value = null;

      try {
        companies.value = await _queryCompaniesFromGemini(query);
      } catch (error) {
        errorText.value = 'Could not search companies: $error';
        companies.value = [];
      } finally {
        isLoading.value = false;
      }
    }

    void openWebsite(CompanySearchResult company) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompanyWebsitePage(
            title: company.name,
            websiteUrl: company.websiteUrl,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Companies',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => searchCompanies(),
          decoration: const InputDecoration(
            labelText: 'Company name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isLoading.value ? null : searchCompanies,
          icon: const Icon(Icons.search),
          label: const Text('Search'),
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
        if (hasSearched.value &&
            companies.value.isEmpty &&
            !isLoading.value) ...[
          const SizedBox(height: 8),
          const Text('No companies matched your query.'),
        ],
        if (companies.value.isNotEmpty) ...[
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: companies.value.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final company = companies.value[index];
                  return Card(
                    child: ListTile(
                      title: Text(company.name),
                      subtitle: TextButton(
                        onPressed: () => openWebsite(company),
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(company.websiteUrl),
                      ),
                      trailing: FilledButton(
                        onPressed: () => onCompanySelected(company),
                        child: const Text('Select'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<List<CompanySearchResult>> _queryCompaniesFromGemini(
    String query) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    generationConfig: GenerationConfig(responseMimeType: 'application/json'),
  );

  final response = await model.generateContent([
    Content.text('''
      Return JSON only in this format:
      {
        "companies": [
          {"name":"Company Name","websiteUrl":"https://example.com"}
        ]
      }

      Task:
      - Find up to 6 likely companies that match the query "$query".
      - Include only real companies and their official website URLs.
      - Use absolute https URLs.
      '''),
  ]);

  final parsedCompanies = _parseCompanies(response.text);
  if (parsedCompanies.isEmpty) {
    throw Exception('No valid companies returned by AI.');
  }
  return parsedCompanies;
}

List<CompanySearchResult> _parseCompanies(String? responseText) {
  if (responseText == null || responseText.trim().isEmpty) {
    return [];
  }

  final jsonPayload = _extractJsonPayload(responseText);
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
      final website =
          _normalizeWebsiteUrl((item['websiteUrl'] as String?) ?? '');
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

String? _normalizeWebsiteUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
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

class CompanyWebsitePage extends HookWidget {
  const CompanyWebsitePage({
    super.key,
    required this.title,
    required this.websiteUrl,
  });

  final String title;
  final String websiteUrl;

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(() {
      return WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(websiteUrl));
    }, [websiteUrl]);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: WebViewWidget(controller: controller),
    );
  }
}
