import 'dart:async';
import 'dart:math' as math;

import 'package:contact_photos/helpers/search_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/screens/image_query/image_query_card.dart';
import 'package:contact_photos/screens/image_query/manual_image_dialog.dart';
import 'package:contact_photos/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CompanyImageSelectedCallback = void Function(CompanyImageOption image);

final Uri _logoKitAttributionUri = Uri.parse('https://logokit.com');

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLoading = useState(false);
    final errorText = useState<String?>(null);
    final hasSearchedWebsite = useState(false);
    final hasSearchedLogosWorld = useState(false);
    final hasSearchedSocial = useState(false);
    final progressValue = useState<double?>(null);
    final progressLabel = useState<String?>(null);

    final noImagesAfterAllLevels = useState(hasSearchedWebsite.value &&
        hasSearchedLogosWorld.value &&
        hasSearchedSocial.value &&
        imageOptions.value.isEmpty);

    Future<void> openLogoKitAttribution() async {
      await launchUrl(
        _logoKitAttributionUri,
        mode: LaunchMode.externalApplication,
      );
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (companyName != null && companyWebsiteUrl != null) {
          SearchHelpers().searchWebsiteImages(
            companyName,
            companyWebsiteUrl,
            errorText,
            imageOptions,
            isLoading,
            hasSearchedWebsite,
            hasSearchedLogosWorld,
            hasSearchedSocial,
            progressValue,
            progressLabel,
          );
        }
      });
      return null;
    }, [imageOptions, companyName, companyWebsiteUrl]);

    Future<void> openManualImageUploadSheet() async {
      unawaited(AnalyticsService.imagePageUploadManualImageButtonTapped());
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => ManualImageDialog(
          onImageSelected: (imageOption) {
            onImageSelected(imageOption);
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(2, 30, 2, 20),
            child: ImageQueryCard(
              companyName: companyName,
              companyWebsiteUrl: companyWebsiteUrl,
              hasSearchedWebsite: hasSearchedWebsite,
              hasSearchedLogosWorld: hasSearchedLogosWorld,
              hasSearchedSocial: hasSearchedSocial,
              isLoading: isLoading,
              errorText: errorText,
              imageOptions: imageOptions,
              progressValue: progressValue,
              progressLabel: progressLabel,
              noImagesAfterAllLevels: noImagesAfterAllLevels,
            )),
        Expanded(
          child: imageOptions.value.isEmpty
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
                    return Stack(
                      children: [
                        GridView.builder(
                          padding: EdgeInsets.only(
                            bottom: hasSearchedWebsite.value && !isLoading.value
                                ? 96
                                : 0,
                          ),
                          itemCount: imageOptions.value.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemBuilder: (context, index) {
                            final imageOption = imageOptions.value[index];
                            return GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Image.memory(
                                        imageOption.bytes,
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                      ),
                                    ),
                                    if (imageOption.isFromLogoKit) ...[
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: openLogoKitAttribution,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: colorScheme.primary,
                                        ),
                                        child: Text(
                                          'Logo provided by LogoKit.com',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Visibility(
                                      visible: !isLoading.value,
                                      child: GlassButton(
                                        icon: const Icon(Icons.check),
                                        label: 'Done',
                                        height: 50,
                                        width: 50,
                                        settings: LiquidGlassSettings(
                                          thickness: 5,
                                          ambientStrength: 0.5,
                                          lightIntensity: 0.8,
                                          lightAngle: 0.75 * math.pi,
                                          glassColor: Colors.blue.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                        onTap: () {
                                          unawaited(AnalyticsService
                                              .imagePageSelectedImage(
                                                  imageUrl: imageOption.url));
                                          onImageSelected(imageOption);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (hasSearchedWebsite.value && !isLoading.value)
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 20,
                            child: GlassButton.custom(
                              onTap: openManualImageUploadSheet,
                              shape: const LiquidRoundedRectangle(
                                borderRadius: 40,
                              ),
                              child: const Text('Upload Your Own Image'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
