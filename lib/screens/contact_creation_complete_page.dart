import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/interactive/glass_button.dart';

typedef FinishFlowCallback = void Function();

class ContactCreationCompletePage extends StatelessWidget {
  const ContactCreationCompletePage({
    required this.onFinish,
    super.key,
  });

  final FinishFlowCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, size: 72),
        const SizedBox(height: 12),
        const Text(
          'Contact Created',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'You are all set. Tap finish to return to the first page.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GlassButton.custom(
          shape: const LiquidRoundedRectangle(
            borderRadius: 40,
          ),
          onTap: onFinish,
          child: const Text('Finish'),
        ),
      ],
    );
  }
}
