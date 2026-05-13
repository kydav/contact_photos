import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/hybrid_company_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef CompanySelectedCallback = void Function(CompanySearchResult company);

class CompanyQueryWidget extends HookWidget {
  const CompanyQueryWidget({
    required this.onCompanySelected,
    super.key,
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
        companies.value = await HybridCompanySearchService.searchCompanies(
          query,
        );
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

    String deriveCompanyNameFromWebsite(String websiteUrl) {
      return websiteUrl.inferCompanyNameFromWebsite(fallback: 'Manual Company');
    }

    Future<void> openManualUrlSheet() async {
      final urlController = TextEditingController();
      String? sheetError;

      final selected = await showModalBottomSheet<CompanySearchResult>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter Company URL',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Website URL',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        final normalized =
                            urlController.text.trim().normalizeWebsiteUrl();
                        if (normalized == null) {
                          setSheetState(() {
                            sheetError = 'Enter a valid website URL.';
                          });
                          return;
                        }

                        Navigator.of(sheetContext).pop(
                          CompanySearchResult(
                            name: deriveCompanyNameFromWebsite(normalized),
                            websiteUrl: normalized,
                          ),
                        );
                      },
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        sheetError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        final normalized =
                            urlController.text.trim().normalizeWebsiteUrl();
                        if (normalized == null) {
                          setSheetState(() {
                            sheetError = 'Enter a valid website URL.';
                          });
                          return;
                        }

                        Navigator.of(sheetContext).pop(
                          CompanySearchResult(
                            name: deriveCompanyNameFromWebsite(normalized),
                            websiteUrl: normalized,
                          ),
                        );
                      },
                      child: const Text('Use This URL'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (selected != null) {
        onCompanySelected(selected);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const Text(
          'Search Companies',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchCompanies(),
              decoration: const InputDecoration(
                labelText: 'Company name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          IconButton.filled(
              onPressed: isLoading.value ? null : searchCompanies,
              icon: const Icon(Icons.search))
        ]),
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
                      title: Row(
                        children: [
                          Text(company.name),
                          IconButton(
                              onPressed: () {
                                final editController =
                                    TextEditingController(text: company.name);
                                final urlController = TextEditingController(
                                    text: company.websiteUrl);
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Edit Company Name'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: editController,
                                            decoration: const InputDecoration(
                                              labelText: 'Company Name',
                                            ),
                                          ),
                                          TextField(
                                            controller: urlController,
                                            decoration: const InputDecoration(
                                              labelText: 'Website URL',
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final newName =
                                                editController.text.trim();
                                            if (newName.isNotEmpty) {
                                              companies.value[index] =
                                                  CompanySearchResult(
                                                name: newName,
                                                websiteUrl: company.websiteUrl,
                                              );
                                            }
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.edit)),
                        ],
                      ),
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
        if (hasSearched.value && !isLoading.value) ...[
          FilledButton.tonalIcon(
            onPressed: openManualUrlSheet,
            icon: const Icon(Icons.link),
            label: const Text('Enter Company URL Manually'),
          ),
        ],
      ],
    );
  }
}

class CompanyWebsitePage extends HookWidget {
  const CompanyWebsitePage({
    required this.title,
    required this.websiteUrl,
    super.key,
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
