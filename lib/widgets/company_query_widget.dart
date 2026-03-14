import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef CompanySelectedCallback = void Function(CompanySearchResult company);

class CompanyQueryWidget extends HookWidget {
  const CompanyQueryWidget({
    required this.onCompanySelected, super.key,
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
        companies.value = await AiService.queryCompaniesFromGemini(query);
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
      spacing: 8,
      children: [
        const Text(
          'Search Companies',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        TextField(
          controller: queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => searchCompanies(),
          decoration: const InputDecoration(
            labelText: 'Company name',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: isLoading.value ? null : searchCompanies,
          icon: const Icon(Icons.search),
          label: const Text('Search'),
        ),
        if (isLoading.value) ...[
          const LinearProgressIndicator(),
        ],
        if (errorText.value != null) ...[
          Text(
            errorText.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (hasSearched.value &&
            companies.value.isEmpty &&
            !isLoading.value) ...[
          const Text('No companies matched your query.'),
        ],
        if (companies.value.isNotEmpty) ...[
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: companies.value.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
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

class CompanyWebsitePage extends HookWidget {
  const CompanyWebsitePage({
    required this.title, required this.websiteUrl, super.key,
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
