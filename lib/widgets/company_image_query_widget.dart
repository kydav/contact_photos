import 'package:contact_photos/helpers/image_logo_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

typedef CompanyImageSelectedCallback = void Function(CompanyImageOption image);

class CompanyImageQueryWidget extends HookWidget {
  const CompanyImageQueryWidget({
    required this.companyName,
    required this.companyWebsiteUrl,
    required this.onImageSelected,
    super.key,
  });

  final String? companyName;
  final String? companyWebsiteUrl;
  final CompanyImageSelectedCallback onImageSelected;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    final errorText = useState<String?>(null);
    final imageOptions = useState<List<CompanyImageOption>>([]);
    final progressValue = useState<double?>(null);
    final progressLabel = useState<String?>(null);

    Future<void> searchCompanyImages() async {
      if (companyName == null || companyWebsiteUrl == null) {
        errorText.value = 'Select a company first to search for images.';
        imageOptions.value = [];
        return;
      }

      isLoading.value = true;
      errorText.value = null;
      imageOptions.value = [];
      progressValue.value = null;
      progressLabel.value = 'Collecting image candidates from website...';

      try {
        final primaryUrls = await ImageLogoHelpers.queryImageUrlsFromWebsite(
          companyName: companyName!,
          websiteUrl: companyWebsiteUrl!,
        );

        progressLabel.value =
            'Validating ${primaryUrls.length} candidate images...';
        imageOptions.value = await ImageLogoHelpers.loadRenderableImageOptions(
          primaryUrls,
          onProgress: (completed, total) {
            if (total <= 0) {
              progressValue.value = null;
              progressLabel.value = 'No image candidates to validate.';
              return;
            }
            progressValue.value = completed / total;
            progressLabel.value = 'Checking image $completed of $total...';
          },
        );

        if (imageOptions.value.length <= 3) {
          progressValue.value = null;
          progressLabel.value = 'Attempting fallback...';

          final logosWorldUrls =
              await ImageLogoHelpers.queryImageUrlsFromLogosWorld(
            companyName: companyName!,
            companyWebsiteUrl: companyWebsiteUrl!,
          );

          if (logosWorldUrls.isNotEmpty) {
            final additionalOptions =
                await ImageLogoHelpers.loadRenderableImageOptions(
              logosWorldUrls,
              onProgress: (completed, total) {
                if (total <= 0) return;
                progressValue.value = completed / total;
                progressLabel.value =
                    'Checking logos-world image $completed of $total...';
              },
            );
            imageOptions.value = ImageLogoHelpers.mergeImageOptions(
              imageOptions.value,
              additionalOptions,
            );
          }
        }

        if (imageOptions.value.isEmpty) {
          errorText.value =
              'No renderable images found from website metadata or assets.';
        } else {
          progressValue.value = 1;
          progressLabel.value = 'Found ${imageOptions.value.length} images.';
        }
      } catch (error) {
        errorText.value = 'Could not search company images: $error';
      } finally {
        isLoading.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Company Images',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text('Company: $companyName'),
        Text('Website: $companyWebsiteUrl'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isLoading.value ? null : searchCompanyImages,
          icon: const Icon(Icons.image_search),
          label: const Text('Search images'),
        ),
        if (isLoading.value) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progressValue.value),
          if (progressLabel.value != null) ...[
            const SizedBox(height: 6),
            Text(
              progressLabel.value!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
        if (errorText.value != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: imageOptions.value.isEmpty
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
                    return GridView.builder(
                      itemCount: imageOptions.value.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, index) {
                        final imageOption = imageOptions.value[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      imageOption.bytes,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: () => onImageSelected(imageOption),
                                  child: const Text('Select'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
