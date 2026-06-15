import 'dart:typed_data';

import 'package:contact_photos/models/company_image_option.dart';
import 'package:contact_photos/screens/image_query/company_image_query_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows LogoKit attribution only for LogoKit images', (
    WidgetTester tester,
  ) async {
    final imageOptions = ValueNotifier<List<CompanyImageOption>>([
      CompanyImageOption(
        url: 'https://img.logokit.com/example.com?token=test-token',
        bytes: _transparentImageBytes,
      ),
      CompanyImageOption(
        url: 'https://example.com/logo.png',
        bytes: _transparentImageBytes,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: CompanyImageQueryWidget(
              companyName: null,
              companyWebsiteUrl: null,
              imageOptions: imageOptions,
              searchGuard: ValueNotifier(false),
              onImageSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Logo provided by LogoKit.com'), findsOneWidget);
  });
}

final Uint8List _transparentImageBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
