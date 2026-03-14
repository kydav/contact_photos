import 'package:contact_photos/helpers/image_logo_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

typedef CompanyImageSelectedCallback = void Function(String imageUrl);

class CompanyImageQueryWidget extends HookWidget {
  const CompanyImageQueryWidget({
    super.key,
    required this.companyName,
    required this.companyWebsiteUrl,
    required this.onImageSelected,
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
          progressLabel.value = 'Trying logos-world.net fallback...';

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
        if (imageOptions.value.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageOptions.value.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final imageOption = imageOptions.value[index];
                return SizedBox(
                  width: 170,
                  child: Card(
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
                            onPressed: () => onImageSelected(imageOption.url),
                            child: const Text('Select'),
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
      ],
    );
  }
}
