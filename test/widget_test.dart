import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tally/home_shell.dart';
import 'package:tally/main.dart';

void main() {
  testWidgets('opens on the Routines tab', (WidgetTester tester) async {
    await tester.pumpWidget(const TallyApp());

    expect(find.widgetWithText(AppBar, 'Routines'), findsOneWidget);
    expect(find.text('No routines yet'), findsOneWidget);
  });

  testWidgets('tapping History switches the visible tab', (
    WidgetTester tester,
  ) async {
    // NoSplash avoids triggering the Material ink-sparkle shader, which
    // this test environment's software renderer can't load.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const HomeShell(),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);
    expect(find.text('No workouts logged yet'), findsOneWidget);
  });
}
