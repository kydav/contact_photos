// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:contact_photos/main.dart';

void main() {
  testWidgets('shows company search and USPS seed data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Search companies'), findsOneWidget);
    expect(find.text('USPS'), findsOneWidget);
    expect(find.text('Text number: 28777'), findsOneWidget);
    expect(find.text('Create'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'citi');
    await tester.pumpAndSettle();

    expect(find.text('Citi Bank'), findsOneWidget);
    expect(find.text('Text number: 692484'), findsOneWidget);
    expect(find.text('USPS'), findsNothing);
  });
}
