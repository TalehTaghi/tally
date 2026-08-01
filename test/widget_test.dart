import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tally/home_shell.dart';
import 'package:tally/main.dart';

void main() {
  testWidgets('opens on the Routines tab', (WidgetTester tester) async {
    await tester.pumpWidget(const TallyApp());

    // RoutinesScreen's data-loading states (spinner/list/empty) are
    // covered by routines_screen_test.dart with a fake DAO; this smoke
    // test only checks that the app boots on the right tab.
    expect(find.widgetWithText(AppBar, 'Routines'), findsOneWidget);
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
