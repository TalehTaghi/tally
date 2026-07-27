import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tally/main.dart';

void main() {
  testWidgets('shows the Tally app bar and body text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TallyApp());

    expect(find.widgetWithText(AppBar, 'Tally'), findsOneWidget);
    expect(find.text('Tally'), findsAtLeastNWidgets(1));
  });
}