import 'dart:async';
import 'dart:io';

import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/services/contacts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_cropper/image_cropper.dart';

typedef ContactCreatedCallback = void Function();

class ContactCreationPage extends HookWidget {
  const ContactCreationPage({
    required this.company,
    required this.imageOption,
    required this.onContactCreated,
    super.key,
  });

  final CompanySearchResult company;
  final CompanyImageOption imageOption;
  final ContactCreatedCallback onContactCreated;

  static Future<Uint8List?> _cropWithImageCropper(Uint8List sourceBytes) async {
    final isSupportedMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isSupportedMobilePlatform) {
      return null;
    }

    final inputFile = File(
      '${Directory.systemTemp.path}/contact_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await inputFile.writeAsBytes(sourceBytes, flush: true);

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: inputFile.path,
      compressQuality: 92,
      maxWidth: 512,
      maxHeight: 512,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Contact Image',
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
            title: 'Adjust Contact Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle),
      ],
    );

    if (croppedFile == null) {
      return null;
    }

    return File(croppedFile.path).readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final phoneController = useTextEditingController();
    final isSaving = useState(false);
    final isCropping = useState(false);
    final localError = useState<String?>(null);
    final contactName = useState(company.name);
    final currentPhotoBytes = useState<Uint8List>(imageOption.bytes);
    final wasCropped = useState(false);

    Future<void> editContactName() async {
      final nameController = TextEditingController(text: contactName.value);
      String? sheetError;

      final updatedName = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
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
                      'Edit Contact Name',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Contact name',
                        border: OutlineInputBorder(),
                      ),
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
                    FilledButton(
                      onPressed: () {
                        final value = nameController.text.trim();
                        if (value.isEmpty) {
                          setSheetState(() {
                            sheetError = 'Name cannot be empty.';
                          });
                          return;
                        }
                        Navigator.of(sheetContext).pop(value);
                      },
                      child: const Text('Save Name'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (updatedName != null && updatedName.isNotEmpty) {
        contactName.value = updatedName;
      }
    }

    Future<void> cropImage() async {
      if (isCropping.value) {
        return;
      }

      isCropping.value = true;
      localError.value = null;
      try {
        final cropped = await _cropWithImageCropper(currentPhotoBytes.value);
        if (cropped != null && cropped.isNotEmpty) {
          currentPhotoBytes.value = cropped;
          wasCropped.value = true;
        } else {
          localError.value =
              'Image cropper is only available on iOS and Android builds.';
        }
      } catch (error) {
        localError.value = 'Could not open image cropper: $error';
      } finally {
        isCropping.value = false;
      }
    }

    Future<void> createContact() async {
      final phoneNumber = phoneController.text.trim();
      if (phoneNumber.isEmpty) {
        localError.value = 'Please enter a phone number.';
        return;
      }

      isSaving.value = true;
      localError.value = null;

      try {
        await ContactsService.createContact(
          companyName: contactName.value,
          phoneNumber: phoneNumber,
          photoBytes: currentPhotoBytes.value,
          photoAlreadyAdjusted: wasCropped.value,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created contact for ${contactName.value}.')),
        );
        onContactCreated();
      } catch (error) {
        if (!context.mounted) return;
        final message = 'Failed to create contact: $error';
        localError.value = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        isSaving.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create Contact',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('Company: ${contactName.value}')),
            IconButton(
              onPressed: isSaving.value ? null : editContactName,
              icon: const Icon(Icons.edit),
              tooltip: 'Edit name',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Adjust Contact Bubble Image',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Center(
          child: ClipOval(
            child: Container(
              width: 140,
              height: 140,
              color: Colors.white,
              child: Image.memory(
                currentPhotoBytes.value,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: (isSaving.value || isCropping.value) ? null : cropImage,
          icon: const Icon(Icons.crop),
          label: Text(isCropping.value ? 'Opening Cropper...' : 'Adjust Image'),
        ),
        if (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS)) ...[
          const SizedBox(height: 6),
          const Text(
            'Image cropper is only available on iOS and Android builds.',
            style: TextStyle(fontSize: 12),
          ),
        ] else ...[
          const SizedBox(height: 6),
          const Text(
            'Tap Adjust Image to crop and resize for the contact bubble.',
            style: TextStyle(fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: isSaving.value ? null : () => unawaited(createContact()),
          child: const Text('Create Contact'),
        ),
        if (isSaving.value) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (localError.value != null) ...[
          const SizedBox(height: 8),
          Text(
            localError.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
