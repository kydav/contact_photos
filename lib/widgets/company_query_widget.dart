import 'dart:math' as math;

import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/hybrid_company_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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

    Future<void> openManualUrlSheet() async {
      final urlController = TextEditingController();
      String? sheetError;

      final selected = await showModalBottomSheet<CompanySearchResult>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return GlassSheet(
                settings: LiquidGlassSettings(
                  blur: 12,
                  thickness: 5,
                  ambientStrength: 0.5,
                  lightIntensity: 0.6,
                  lightAngle: 0.75 * math.pi,
                  glassColor: Colors.white.withValues(alpha: 0.12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Company URL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GlassTextField(
                        controller: urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        shape: const LiquidRoundedRectangle(borderRadius: 40),
                        settings: LiquidGlassSettings(
                          thickness: 5,
                          ambientStrength: 0.5,
                          lightIntensity: 0.8,
                          lightAngle: 0.75 * math.pi,
                          glassColor: Colors.blue.withValues(alpha: 0.1),
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
                              name: normalized.inferCompanyNameFromWebsite(
                                  fallback: 'Manual Company'),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 10,
                        children: [
                          GlassButton(
                            icon: const Icon(Icons.close),
                            label: 'Cancel',
                            height: 50,
                            width: 50,
                            settings: LiquidGlassSettings(
                              thickness: 5,
                              ambientStrength: 0.5,
                              lightIntensity: 0.8,
                              lightAngle: 0.75 * math.pi,
                              glassColor: Colors.blue.withValues(alpha: 0.1),
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                          GlassButton(
                            icon: const Icon(Icons.check),
                            label: 'Done',
                            height: 50,
                            width: 50,
                            settings: LiquidGlassSettings(
                              thickness: 5,
                              ambientStrength: 0.5,
                              lightIntensity: 0.8,
                              lightAngle: 0.75 * math.pi,
                              glassColor: Colors.blue.withValues(alpha: 0.1),
                            ),
                            onTap: () {
                              final normalized = urlController.text
                                  .trim()
                                  .normalizeWebsiteUrl();
                              if (normalized == null) {
                                setSheetState(() {
                                  sheetError = 'Enter a valid website URL.';
                                });
                                return;
                              }
                              Navigator.of(sheetContext).pop(
                                CompanySearchResult(
                                  name: normalized.inferCompanyNameFromWebsite(
                                      fallback: 'Manual Company'),
                                  websiteUrl: normalized,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          const SizedBox(
            height: 20,
          ),
          Row(children: [
            Expanded(
              child: GlassSearchBar(
                controller: queryController,
                onSubmitted: (_) => searchCompanies(),
              ),
            ),
          ]),
          if (isLoading.value) ...[
            const Center(child: GlassProgressIndicator.linear())
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
                    return GlassCard(
                      shape: const LiquidRoundedRectangle(borderRadius: 20),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 1, vertical: 2),
                        title: Text(company.name),
                        subtitle: Text(company.websiteUrl),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 5,
                          children: [
                            GlassButton(
                              icon: const Icon(Icons.edit),
                              label: 'Edit',
                              height: 50,
                              width: 50,
                              settings: LiquidGlassSettings(
                                thickness: 5,
                                ambientStrength: 0.5,
                                lightIntensity: 0.8,
                                lightAngle: 0.75 * math.pi,
                                glassColor: Colors.blue.withValues(alpha: 0.1),
                              ),
                              onTap: () {
                                final editController =
                                    TextEditingController(text: company.name);
                                final urlController = TextEditingController(
                                    text: company.websiteUrl);
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return GlassDialog(
                                      title: 'Edit Company Name',
                                      maxWidth: double.infinity,
                                      settings: LiquidGlassSettings(
                                        blur: 12,
                                        thickness: 5,
                                        ambientStrength: 0.5,
                                        lightIntensity: 0.6,
                                        lightAngle: 0.75 * math.pi,
                                        glassColor: Colors.white
                                            .withValues(alpha: 0.08),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: 10,
                                        children: [
                                          GlassTextField(
                                            controller: editController,
                                            placeholder: 'Company Name',
                                          ),
                                          GlassTextField(
                                              controller: urlController,
                                              placeholder: 'Website URL'),
                                        ],
                                      ),
                                      actions: [
                                        GlassDialogAction(
                                            label: 'Cancel',
                                            onPressed: () =>
                                                Navigator.of(context).pop()),
                                        GlassDialogAction(
                                          label: 'Save',
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
                                        )
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                            GlassButton(
                              icon: const Icon(Icons.check),
                              label: 'Done',
                              height: 50,
                              width: 50,
                              settings: LiquidGlassSettings(
                                thickness: 5,
                                ambientStrength: 0.5,
                                lightIntensity: 0.8,
                                lightAngle: 0.75 * math.pi,
                                glassColor: Colors.blue.withValues(alpha: 0.1),
                              ),
                              onTap: () => onCompanySelected(company),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (hasSearched.value && !isLoading.value) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20),
              child: GlassButton.custom(
                onTap: openManualUrlSheet,
                shape: const LiquidRoundedRectangle(borderRadius: 40),
                child: const Text('Enter Company URL Manually'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
