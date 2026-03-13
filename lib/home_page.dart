import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:contact_photos/widgets/company_query_widget.dart';
import 'package:contact_photos/widgets/company_image_query_widget.dart';

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedCompany = useState<CompanySearchResult?>(null);
    final controller = usePageController();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Contact')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PageView(
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            CompanyQueryWidget(
              onCompanySelected: (company) {
                selectedCompany.value = company;
                controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            CompanyImageQueryWidget(
              companyName: selectedCompany.value?.name,
              companyWebsiteUrl: selectedCompany.value?.websiteUrl,
              onImageSelected: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}
