import 'dart:typed_data';

import 'package:contact_photos/helpers/search_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';

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
                      'Upload Your Own Image',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an image from your device to use for this contact.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          isPicking ? null : () => pickImage(setSheetState),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        isPicking ? 'Picking image...' : 'Choose Image',
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
              );
            },
          );
        },
      );
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
        if (hasSearchedWebsite.value && !hasSearchedLogosWorld.value) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isLoading.value
                ? null
                : () => SearchHelpers().searchLogosWorldImages(
                      companyName,
                      companyWebsiteUrl,
                      errorText,
                      imageOptions,
                      isLoading,
                      hasSearchedLogosWorld,
                      progressValue,
                      progressLabel,
                    ),
            icon: const Icon(Icons.travel_explore),
            label: const Text('Keep searching'),
          ),
        ],
        if (hasSearchedLogosWorld.value && !hasSearchedSocial.value) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isLoading.value
                ? null
                : () => SearchHelpers().searchSocialImages(
                      companyName,
                      companyWebsiteUrl,
                      errorText,
                      imageOptions,
                      isLoading,
                      hasSearchedSocial,
                      progressValue,
                      progressLabel,
                    ),
            icon: const Icon(Icons.public),
            label: const Text('Keep searching'),
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
            'No images were found after checking all available options, please upload an image.',
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
                                Visibility(
                                  visible: !isLoading.value,
                                  child: FilledButton(
                                    onPressed: () =>
                                        onImageSelected(imageOption),
                                    child: const Text('Select'),
                                  ),
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
        if (hasSearchedWebsite.value && !isLoading.value) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: openManualImageUploadSheet,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Your Own Image'),
          ),
        ],
      ],
    );
  }
}
