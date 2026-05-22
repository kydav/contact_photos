import 'dart:math' as math;

import 'package:contact_photos/extensions/string_extensions.dart';
import 'package:contact_photos/models/company_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ManualCompanyDialog extends HookWidget {
  const ManualCompanyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final sheetError = useState<String?>(null);
    final urlController = useTextEditingController();

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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Company URL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            GlassTextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              shape: const LiquidRoundedRectangle(borderRadius: 40),
              settings: LiquidGlassSettings(
                thickness: 5,
                ambientStrength: 0.5,
                lightIntensity: 0.8,
                lightAngle: 0.75 * math.pi,
                glassColor: Colors.blue.withValues(alpha: 0.1),
              ),
              onSubmitted: (_) {
                final normalized =
                    urlController.text.trim().normalizeWebsiteUrl();
                if (normalized == null) {
                  sheetError.value = 'Enter a valid website URL.';
                  return;
                }

                Navigator.of(context).pop(
                  CompanySearchResult(
                    name: normalized.inferCompanyNameFromWebsite(
                        fallback: 'Manual Company'),
                    websiteUrl: normalized,
                  ),
                );
              },
            ),
            if (sheetError.value != null) ...[
              const SizedBox(height: 8),
              Text(
                sheetError.value!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 10,
              children: [
                GlassButton(
                  icon: const Icon(Icons.close),
                  label: 'Cancel',
                  height: 50,
                  width: 50,
                  settings: LiquidGlassSettings(
                    thickness: 5,
                    ambientStrength: 0.5,
                    lightIntensity: 0.8,
                    lightAngle: 0.75 * math.pi,
                    glassColor: Colors.blue.withValues(alpha: 0.1),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                GlassButton(
                  icon: const Icon(Icons.check),
                  label: 'Done',
                  height: 50,
                  width: 50,
                  settings: LiquidGlassSettings(
                    thickness: 5,
                    ambientStrength: 0.5,
                    lightIntensity: 0.8,
                    lightAngle: 0.75 * math.pi,
                    glassColor: Colors.blue.withValues(alpha: 0.1),
                  ),
                  onTap: () {
                    final normalized =
                        urlController.text.trim().normalizeWebsiteUrl();
                    if (normalized == null) {
                      sheetError.value = 'Enter a valid website URL.';
                      return;
                    }
                    Navigator.of(context).pop(
                      CompanySearchResult(
                        name: normalized.inferCompanyNameFromWebsite(
                            fallback: 'Manual Company'),
                        websiteUrl: normalized,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
