// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:contact_photos/main.dart';

void main() {
  testWidgets('shows onboarding flow controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Step 1: Scan message senders'), findsOneWidget);
    expect(find.text('Scan senders'), findsOneWidget);
    expect(find.text('Step 2: Enter company name'), findsOneWidget);
    expect(find.text('Company name'), findsOneWidget);
    expect(find.text('Generate image options'), findsOneWidget);
    expect(find.text('Create contact'), findsOneWidget);
  });
}
