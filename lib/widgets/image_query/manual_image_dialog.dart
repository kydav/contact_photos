import 'dart:math' as math;
import 'dart:typed_data';

import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/widgets/company_image_query_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ManualImageDialog extends HookWidget {
  const ManualImageDialog({required this.onImageSelected, super.key});

  final CompanyImageSelectedCallback onImageSelected;

  @override
  Widget build(BuildContext context) {
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
            localSheetError = 'Could not read image bytes. Try another image.';
          });
          return;
        }

        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();

        onImageSelected(
          CompanyImageOption(
            url: 'manual-upload://${DateTime.now().millisecondsSinceEpoch}',
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
  }
}
