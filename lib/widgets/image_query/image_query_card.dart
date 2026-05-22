import 'package:contact_photos/helpers/search_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ImageQueryCard extends StatelessWidget {
  const ImageQueryCard(
      {required this.hasSearchedWebsite,
      required this.hasSearchedLogosWorld,
      required this.hasSearchedSocial,
      required this.isLoading,
      required this.errorText,
      required this.imageOptions,
      required this.progressValue,
      required this.progressLabel,
      required this.noImagesAfterAllLevels,
      this.companyName,
      this.companyWebsiteUrl,
      super.key});

  final String? companyName;
  final String? companyWebsiteUrl;
  final ValueNotifier<bool> hasSearchedWebsite;
  final ValueNotifier<bool> hasSearchedLogosWorld;
  final ValueNotifier<bool> hasSearchedSocial;
  final ValueNotifier<bool> isLoading;
  final ValueNotifier<String?> errorText;
  final ValueNotifier<List<CompanyImageOption>> imageOptions;
  final ValueNotifier<double?> progressValue;
  final ValueNotifier<String?> progressLabel;
  final ValueNotifier<bool> noImagesAfterAllLevels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName ?? 'Unknown company',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(companyWebsiteUrl ?? 'No website found',
                          style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Review the results below or upload your own image.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
              ),
            ),
            if (hasSearchedWebsite.value && !hasSearchedLogosWorld.value) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: GlassButton.custom(
                  enabled: !isLoading.value,
                  onTap: () => SearchHelpers().searchLogosWorldImages(
                    companyName,
                    companyWebsiteUrl,
                    errorText,
                    imageOptions,
                    isLoading,
                    hasSearchedLogosWorld,
                    progressValue,
                    progressLabel,
                  ),
                  shape: const LiquidRoundedRectangle(
                    borderRadius: 40,
                  ),
                  child: const Text('Keep searching'),
                ),
              ),
            ],
            if (hasSearchedLogosWorld.value && !hasSearchedSocial.value) ...[
              const SizedBox(height: 14),
              GlassButton.custom(
                enabled: !isLoading.value,
                onTap: () => SearchHelpers().searchSocialImages(
                  companyName,
                  companyWebsiteUrl,
                  errorText,
                  imageOptions,
                  isLoading,
                  hasSearchedSocial,
                  progressValue,
                  progressLabel,
                ),
                shape: const LiquidRoundedRectangle(
                  borderRadius: 40,
                ),
                child: const Text('Keep searching'),
              ),
            ],
            if (isLoading.value) ...[
              const SizedBox(height: 14),
              Center(
                child: GlassProgressIndicator.linear(
                  value: progressValue.value,
                ),
              ),
              if (progressLabel.value != null) ...[
                const SizedBox(height: 6),
                Text(
                  progressLabel.value!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            if (errorText.value != null) ...[
              const SizedBox(height: 12),
              Text(
                errorText.value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            if (noImagesAfterAllLevels.value) ...[
              const SizedBox(height: 12),
              Text(
                'No images were found after checking all available options, please upload an image.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
