// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:contact_photos/main.dart';
import 'package:contact_photos/screens/company_query/company_query_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows company query widget on home page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(initialIntroShown: true));

    expect(find.text('Search Companies'), findsOneWidget);
    expect(find.byType(CompanyQueryWidget), findsOneWidget);
  });
}
