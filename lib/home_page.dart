import 'dart:async';

import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/screens/contact_creation_complete_page.dart';
import 'package:contact_photos/screens/contact_creation_page.dart';
import 'package:contact_photos/ui/background.dart';
import 'package:contact_photos/widgets/company_image_query_widget.dart';
import 'package:contact_photos/widgets/company_query_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedCompany = useState<CompanySearchResult?>(null);
    final selectedImage = useState<CompanyImageOption?>(null);
    final controller = usePageController();
    final currentPageIndex = useState(0);
    final showLeading = useState(false);
    final resetSeed = useState(0);
    final imageStepSeed = useState(0);
    final imageOptions = useState<List<CompanyImageOption>>([]);

    useEffect(() {
      void listener() {
        currentPageIndex.value = controller.page?.round() ?? 0;
        showLeading.value = controller.page != null &&
            controller.page! > 0.01 &&
            controller.page! < 2.99;
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    Future<void> goToPage(int page) async {
      currentPageIndex.value = page;
      await controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    Future<void> finishAndReset() async {
      selectedCompany.value = null;
      selectedImage.value = null;
      resetSeed.value = resetSeed.value + 1;
      imageOptions.value = [];
      await goToPage(0);
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: switch (currentPageIndex.value) {
              0 => const Text('Search Companies'),
              1 => const Text('Select Image'),
              2 => const Text('Create Contact'),
              3 => const Text('Complete'),
              _ => null,
            },
            centerTitle: false,
            leading: showLeading.value
                ? IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  )
                : null),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PageView(
            controller: controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              KeyedSubtree(
                key: ValueKey<String>('search-${resetSeed.value}'),
                child: CompanyQueryWidget(
                  onCompanySelected: (company) {
                    selectedCompany.value = company;
                    selectedImage.value = null;
                    imageOptions.value = [];
                    imageStepSeed.value = imageStepSeed.value + 1;
                    unawaited(goToPage(1));
                  },
                ),
              ),
              KeyedSubtree(
                key: ValueKey<String>(
                  'images-${resetSeed.value}-${imageStepSeed.value}',
                ),
                child: CompanyImageQueryWidget(
                  companyName: selectedCompany.value?.name,
                  companyWebsiteUrl: selectedCompany.value?.websiteUrl,
                  imageOptions: imageOptions,
                  onImageSelected: (imageOption) {
                    selectedImage.value = imageOption;
                    unawaited(goToPage(2));
                  },
                ),
              ),
              if (selectedCompany.value != null && selectedImage.value != null)
                KeyedSubtree(
                  key: ValueKey<String>('contact-${resetSeed.value}'),
                  child: ContactCreationPage(
                    company: selectedCompany.value!,
                    imageOption: selectedImage.value!,
                    onContactCreated: () => unawaited(goToPage(3)),
                  ),
                )
              else
                const Center(child: Text('Select a company and image first.')),
              ContactCreationCompletePage(
                onFinish: () => unawaited(finishAndReset()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
