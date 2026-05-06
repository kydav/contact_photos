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
    required this.imageOptions,
    super.key,
  });

  final String? companyName;
  final String? companyWebsiteUrl;
  final CompanyImageSelectedCallback onImageSelected;
  final ValueNotifier<List<CompanyImageOption>> imageOptions;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    final errorText = useState<String?>(null);
    final hasSearchedWebsite = useState(false);
    final hasSearchedLogosWorld = useState(false);
    final hasSearchedSocial = useState(false);

    final progressValue = useState<double?>(null);
    final progressLabel = useState<String?>(null);
    final noImagesAfterAllLevels = hasSearchedWebsite.value &&
        hasSearchedLogosWorld.value &&
        hasSearchedSocial.value &&
        imageOptions.value.isEmpty;

    Future<void> searchWebsiteImages() async {
      if (companyName == null || companyWebsiteUrl == null) {
        errorText.value = 'Select a company first to search for images.';
        imageOptions.value = [];
        return;
      }

      isLoading.value = true;
      errorText.value = null;
      imageOptions.value = [];
      hasSearchedWebsite.value = false;
      hasSearchedLogosWorld.value = false;
      hasSearchedSocial.value = false;
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
        hasSearchedWebsite.value = true;

        if (imageOptions.value.length <= 3) {
          progressValue.value = null;
          progressLabel.value =
              'Auto fallback: collecting additional candidates...';

          final logosWorldUrls =
              await ImageLogoHelpers.queryImageUrlsFromLogosWorld(
            companyName: companyName!,
            companyWebsiteUrl: companyWebsiteUrl!,
          );
          hasSearchedLogosWorld.value = true;

          if (logosWorldUrls.isNotEmpty) {
            final logosWorldOptions =
                await ImageLogoHelpers.loadRenderableImageOptions(
              logosWorldUrls,
              onProgress: (completed, total) {
                if (total <= 0) return;
                progressValue.value = completed / total;
                progressLabel.value =
                    'Auto fallback: checking additional image $completed of $total...';
              },
            );
            imageOptions.value = ImageLogoHelpers.mergeImageOptions(
              imageOptions.value,
              logosWorldOptions,
            );
          }
        }

        if (imageOptions.value.length <= 3) {
          progressValue.value = null;
          progressLabel.value = 'Auto fallback: collecting more candidates...';

          final socialUrls =
              await ImageLogoHelpers.queryImageUrlsFromSocialProfiles(
            companyName: companyName!,
            companyWebsiteUrl: companyWebsiteUrl!,
          );
          hasSearchedSocial.value = true;

          if (socialUrls.isNotEmpty) {
            final socialOptions =
                await ImageLogoHelpers.loadRenderableImageOptions(
              socialUrls,
              allowSocialAssetUrls: true,
              onProgress: (completed, total) {
                if (total <= 0) return;
                progressValue.value = completed / total;
                progressLabel.value =
                    'Auto fallback: checking more image $completed of $total...';
              },
            );
            imageOptions.value = ImageLogoHelpers.mergeImageOptions(
              imageOptions.value,
              socialOptions,
            );
          }
        }

        if (imageOptions.value.isEmpty) {
          errorText.value =
              'No renderable images were found from configured search sources.';
          progressLabel.value = 'No images found after all fallback levels.';
        } else {
          progressValue.value = 1;
          progressLabel.value = 'Found ${imageOptions.value.length} image(s).';
        }
      } catch (error) {
        errorText.value = 'Could not search company images: $error';
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> searchLogosWorldImages() async {
      if (companyName == null || companyWebsiteUrl == null) {
        errorText.value = 'Select a company first to search for images.';
        return;
      }

      isLoading.value = true;
      errorText.value = null;
      progressValue.value = null;
      progressLabel.value = 'Collecting fallback candidates...';

      try {
        final logosWorldUrls =
            await ImageLogoHelpers.queryImageUrlsFromLogosWorld(
          companyName: companyName!,
          companyWebsiteUrl: companyWebsiteUrl!,
        );

        if (logosWorldUrls.isEmpty) {
          hasSearchedLogosWorld.value = true;
          progressLabel.value = 'No fallback candidates found.';
          return;
        }

        final additionalOptions =
            await ImageLogoHelpers.loadRenderableImageOptions(
          logosWorldUrls,
          onProgress: (completed, total) {
            if (total <= 0) return;
            progressValue.value = completed / total;
            progressLabel.value =
                'Checking fallback image $completed of $total...';
          },
        );

        imageOptions.value = ImageLogoHelpers.mergeImageOptions(
          imageOptions.value,
          additionalOptions,
        );
        hasSearchedLogosWorld.value = true;

        if (additionalOptions.isEmpty) {
          progressLabel.value =
              'No renderable fallback images found. Try deeper fallback.';
        } else {
          progressValue.value = 1;
          progressLabel.value =
              'Added ${additionalOptions.length} fallback image(s).';
        }
      } catch (error) {
        errorText.value = 'Could not run fallback search: $error';
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> searchSocialImages() async {
      if (companyName == null || companyWebsiteUrl == null) {
        errorText.value = 'Select a company first to search for images.';
        return;
      }

      isLoading.value = true;
      errorText.value = null;
      progressValue.value = null;
      progressLabel.value = 'Collecting deeper fallback candidates...';

      try {
        final socialUrls =
            await ImageLogoHelpers.queryImageUrlsFromSocialProfiles(
          companyName: companyName!,
          companyWebsiteUrl: companyWebsiteUrl!,
        );

        if (socialUrls.isEmpty) {
          hasSearchedSocial.value = true;
          progressLabel.value = 'No deeper fallback candidates found.';
          return;
        }

        final socialOptions = await ImageLogoHelpers.loadRenderableImageOptions(
          socialUrls,
          allowSocialAssetUrls: true,
          onProgress: (completed, total) {
            if (total <= 0) return;
            progressValue.value = completed / total;
            progressLabel.value =
                'Checking deeper fallback image $completed of $total...';
          },
        );

        imageOptions.value = ImageLogoHelpers.mergeImageOptions(
          imageOptions.value,
          socialOptions,
        );
        hasSearchedSocial.value = true;

        if (socialOptions.isEmpty) {
          progressLabel.value = 'No renderable deeper fallback images found.';
        } else {
          progressValue.value = 1;
          progressLabel.value =
              'Added ${socialOptions.length} deeper fallback image(s).';
        }
      } catch (error) {
        errorText.value = 'Could not run deeper fallback search: $error';
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
          onPressed: isLoading.value ? null : searchWebsiteImages,
          icon: const Icon(Icons.image_search),
          label: const Text('Search website images'),
        ),
        if (hasSearchedWebsite.value && !hasSearchedLogosWorld.value) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isLoading.value ? null : searchLogosWorldImages,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Run fallback search'),
          ),
        ],
        if (hasSearchedLogosWorld.value && !hasSearchedSocial.value) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isLoading.value ? null : searchSocialImages,
            icon: const Icon(Icons.public),
            label: const Text('Run deeper fallback'),
          ),
        ],
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
        if (noImagesAfterAllLevels) ...[
          const SizedBox(height: 8),
          Text(
            'No images were found after checking all available levels.',
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
