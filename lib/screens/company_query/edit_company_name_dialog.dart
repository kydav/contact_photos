import 'dart:math' as math;

import 'package:contact_photos/models/company_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class EditCompanyNameDialog extends HookWidget {
  const EditCompanyNameDialog({required this.companySearchResult, super.key});

  final CompanySearchResult companySearchResult;

  @override
  Widget build(BuildContext context) {
    final editController =
        useTextEditingController(text: companySearchResult.name);
    final urlController =
        useTextEditingController(text: companySearchResult.websiteUrl);
    return GlassDialog(
      title: 'Edit Company Name',
      maxWidth: double.infinity,
      settings: LiquidGlassSettings(
        blur: 12,
        thickness: 5,
        ambientStrength: 0.5,
        lightIntensity: 0.6,
        lightAngle: 0.75 * math.pi,
        glassColor: Colors.white.withValues(alpha: 0.08),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          GlassTextField(
            controller: editController,
            placeholder: 'Company Name',
          ),
          GlassTextField(controller: urlController, placeholder: 'Website URL'),
        ],
      ),
      actions: [
        GlassDialogAction(
            label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
        GlassDialogAction(
          label: 'Save',
          onPressed: () {
            Navigator.of(context).pop(CompanySearchResult(
              name: editController.text.trim(),
              websiteUrl: urlController.text.trim(),
            ));
          },
        )
      ],
    );
  }
}
