import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:contact_photos/screens/contact_creation_page/update_name_dialog.dart';
import 'package:contact_photos/screens/paywall/paywall_screen.dart';
import 'package:contact_photos/services/contacts_service.dart';
import 'package:contact_photos/services/preferences_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

typedef ContactCreatedCallback = void Function();

enum _BubbleBackground {
  white,
  black,
}

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

  static bool _hasTransparency(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return false;
    }

    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        if (decoded.getPixel(x, y).a < 255) {
          return true;
        }
      }
    }
    return false;
  }

  static Uint8List _composeBubbleReadyImage(
    Uint8List sourceBytes,
    _BubbleBackground background,
  ) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return sourceBytes;
    }

    const targetSize = 512;
    final maxDimension =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (maxDimension == 0) {
      return sourceBytes;
    }

    final fitScale = targetSize / maxDimension.toDouble();
    final resizedWidth =
        (decoded.width * fitScale).round().clamp(1, targetSize);
    final resizedHeight =
        (decoded.height * fitScale).round().clamp(1, targetSize);

    final resized = img.copyResize(
      decoded,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.average,
    );

    final canvas = img.Image(width: targetSize, height: targetSize);
    final color = background == _BubbleBackground.black
        ? img.ColorRgb8(0, 0, 0)
        : img.ColorRgb8(255, 255, 255);
    img.fill(canvas, color: color);

    final offsetX = (targetSize - resized.width) ~/ 2;
    final offsetY = (targetSize - resized.height) ~/ 2;
    img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }

  static Uint8List _encodeCropperImage(
    img.Image image, {
    required bool preserveTransparency,
    int jpgQuality = 95,
  }) {
    return Uint8List.fromList(
      preserveTransparency
          ? img.encodePng(image)
          : img.encodeJpg(image, quality: jpgQuality),
    );
  }

  static Uint8List _prepareSourceBytesForCropper(
    Uint8List sourceBytes, {
    required bool preserveTransparency,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return sourceBytes;
    }

    final aspectRatio = decoded.width / decoded.height;
    final needsPadding = aspectRatio > 1.2 || aspectRatio < 0.83;
    if (!needsPadding) {
      return sourceBytes;
    }

    final maxDim =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final canvasSize = (maxDim * 1.28).round();

    final canvas = img.Image(width: canvasSize, height: canvasSize);
    img.fill(
      canvas,
      color: preserveTransparency
          ? img.ColorRgba8(0, 0, 0, 0)
          : img.ColorRgb8(255, 255, 255),
    );

    final offsetX = (canvas.width - decoded.width) ~/ 2;
    final offsetY = (canvas.height - decoded.height) ~/ 2;
    img.compositeImage(canvas, decoded, dstX: offsetX, dstY: offsetY);

    return _encodeCropperImage(
      canvas,
      preserveTransparency: preserveTransparency,
    );
  }

  static Future<Uint8List?> _cropWithImageCropper(Uint8List sourceBytes) async {
    final isSupportedMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isSupportedMobilePlatform) {
      return null;
    }

    final preserveTransparency = _hasTransparency(sourceBytes);
    final preparedBytes = _prepareSourceBytesForCropper(
      sourceBytes,
      preserveTransparency: preserveTransparency,
    );
    final fileExtension = preserveTransparency ? 'png' : 'jpg';

    final inputFile = File(
      '${Directory.systemTemp.path}/contact_photo_${DateTime.now().millisecondsSinceEpoch}.$fileExtension',
    );
    await inputFile.writeAsBytes(preparedBytes, flush: true);

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: inputFile.path,
      compressQuality: preserveTransparency ? 100 : 92,
      compressFormat: preserveTransparency
          ? ImageCompressFormat.png
          : ImageCompressFormat.jpg,
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
    final bubbleBackground = useState(_BubbleBackground.white);
    final theme = Theme.of(context);

    final hasTransparentBackground = useMemoized(
      () => _hasTransparency(currentPhotoBytes.value),
      [currentPhotoBytes.value],
    );

    final previewPhotoBytes = useMemoized(
      () => hasTransparentBackground
          ? _composeBubbleReadyImage(
              currentPhotoBytes.value, bubbleBackground.value)
          : currentPhotoBytes.value,
      [
        currentPhotoBytes.value,
        hasTransparentBackground,
        bubbleBackground.value
      ],
    );

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

      // Paywall gate: check entitlement before creating the contact.
      final isUnlocked = await PreferencesService.isPurchaseUnlocked();
      if (!isUnlocked) {
        final count = await PreferencesService.getContactsCreated();
        if (count >= 3) {
          if (!context.mounted) return;
          final unlocked = await PaywallScreen.show(context);
          if (unlocked != true) {
            return;
          }
        }
      }

      isSaving.value = true;
      localError.value = null;

      try {
        await ContactsService.createContact(
          companyName: contactName.value,
          phoneNumber: phoneNumber,
          url: company.websiteUrl,
          photoBytes: previewPhotoBytes,
          photoAlreadyAdjusted: wasCropped.value || hasTransparentBackground,
        );
        await PreferencesService.incrementContactsCreated();
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 30, 2, 20),
            child: GlassCard(
              child: Stack(
                children: [
                  Positioned(
                    top: 2,
                    right: 0,
                    child: GlassButton(
                      shape: const LiquidRoundedRectangle(borderRadius: 40),
                      enabled: !isSaving.value && !isCropping.value,
                      onTap: cropImage,
                      icon: const Icon(Icons.crop),
                      settings: LiquidGlassSettings(
                        thickness: 5,
                        ambientStrength: 0.5,
                        lightIntensity: 0.8,
                        lightAngle: 0.75 * math.pi,
                        glassColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 0,
                    child: GlassButton(
                      enabled: !isSaving.value,
                      onTap: () async {
                        final updatedName = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (sheetContext) =>
                              UpdateNameDialog(name: contactName.value),
                        );

                        if (updatedName != null && updatedName.isNotEmpty) {
                          contactName.value = updatedName;
                        }
                      },
                      icon: const Icon(Icons.edit),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: Container(
                            width: 140,
                            height: 140,
                            color: bubbleBackground.value ==
                                    _BubbleBackground.black
                                ? Colors.black
                                : Colors.white,
                            child: Image.memory(
                              previewPhotoBytes,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    contactName.value,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(company.websiteUrl,
                                      style: theme.textTheme.bodyLarge),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasTransparentBackground) ...[
            const SizedBox(height: 8),
            const Text('Transparent background detected. Bubble background:'),
            RadioGroup<_BubbleBackground>(
              groupValue: bubbleBackground.value,
              onChanged: (value) {
                if (!isSaving.value && value != null) {
                  bubbleBackground.value = value;
                }
              },
              child: const Column(
                children: [
                  RadioListTile<_BubbleBackground>(
                    dense: true,
                    value: _BubbleBackground.white,
                    title: Text('White'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<_BubbleBackground>(
                    dense: true,
                    value: _BubbleBackground.black,
                    title: Text('Black'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          GlassTextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            placeholder: 'Enter phone number',
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          if (localError.value != null) ...[
            const SizedBox(height: 8),
            Text(
              localError.value!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 10),
          GlassButton.custom(
            enabled: !isSaving.value,
            onTap: () => unawaited(createContact()),
            shape: const LiquidRoundedRectangle(borderRadius: 40),
            child: const Text('Create Contact'),
          ),
          if (isSaving.value) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
