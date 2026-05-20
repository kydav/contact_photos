import 'dart:math' as math;
import 'dart:typed_data';

import 'package:contact_photos/helpers/search_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          var isPicking = false;
          String? localSheetError;

          Future<void> pickImage(StateSetter setSheetState) async {
            if (isPicking) {
              return;
            }

            setSheetState(() {
              isPicking = true;
              localSheetError = null;
            });

            try {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 100,
              );
              if (file == null) {
                setSheetState(() {
                  isPicking = false;
                });
                return;
              }

              final bytes = await file.readAsBytes();
              if (bytes.isEmpty) {
                setSheetState(() {
                  isPicking = false;
                  localSheetError =
                      'Could not read image bytes. Try another image.';
                });
                return;
              }

              if (!sheetContext.mounted) {
                return;
              }
              Navigator.of(sheetContext).pop();

              onImageSelected(
                CompanyImageOption(
                  url:
                      'manual-upload://${DateTime.now().millisecondsSinceEpoch}',
                  bytes: Uint8List.fromList(bytes),
                ),
              );
            } catch (error) {
              setSheetState(() {
                isPicking = false;
                localSheetError = 'Could not pick image: $error';
              });
            }
          }

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
                        'Upload Your Own Image',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose an image from your device to use for this contact.',
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: GlassButton.custom(
                          enabled: !isPicking,
                          onTap: () => pickImage(setSheetState),
                          shape: const LiquidRoundedRectangle(borderRadius: 40),
                          child: Text(
                            isPicking ? 'Picking image...' : 'Choose Image',
                          ),
                        ),
                      ),
                      if (localSheetError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          localSheetError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
                      'Review the results below or continue searching for stronger logo matches.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                      ),
                    ),
                    if (hasSearchedWebsite.value &&
                        !hasSearchedLogosWorld.value) ...[
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
                    if (hasSearchedLogosWorld.value &&
                        !hasSearchedSocial.value) ...[
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
                    if (noImagesAfterAllLevels) ...[
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
            ),
          ),
        ),
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
                                        onTap: () =>
                                            onImageSelected(imageOption),
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
                            bottom: 8,
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
