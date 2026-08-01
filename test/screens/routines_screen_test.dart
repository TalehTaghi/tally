import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/models/routine.dart';
import 'package:tally/screens/new_routine_screen.dart';
import 'package:tally/screens/routines_screen.dart';

import '../support/fake_daos.dart';

void main() {
  Widget hostedScreen(FakeRoutineDao dao) {
    // NoSplash avoids triggering the Material ink-sparkle shader, which
    // this test environment's software renderer can't load.
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: RoutinesScreen(routineDao: dao),
    );
  }

  testWidgets('shows a spinner while loading', (tester) async {
    final dao = FakeRoutineDao([])..blockNextGetAll();

    await tester.pumpWidget(hostedScreen(dao));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an empty-state message when there are no routines', (
    tester,
  ) async {
    final dao = FakeRoutineDao([]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    expect(find.textContaining('No routines yet'), findsOneWidget);
  });

  testWidgets('lists routines newest first', (tester) async {
    final dao = FakeRoutineDao([
      Routine(id: 1, name: 'Push Day', createdAt: DateTime(2026, 1, 1)),
      Routine(id: 2, name: 'Pull Day', createdAt: DateTime(2026, 1, 5)),
    ]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data)
        .toList();

    expect(titles, ['Pull Day', 'Push Day']);
  });

  testWidgets('tapping + opens the New Routine screen', (tester) async {
    final dao = FakeRoutineDao([]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'New Routine'), findsOneWidget);
  });

  testWidgets('refreshes the list after a routine is created', (
    tester,
  ) async {
    final dao = FakeRoutineDao([]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();
    expect(find.textContaining('No routines yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // New Routine screen's own save flow is covered by
    // new_routine_screen_test.dart. Here we only need to prove that
    // RoutinesScreen refetches once a `true` result comes back from the
    // pushed route — so simulate that result directly.
    dao.addRoutine(
      Routine(id: 1, name: 'Push Day', createdAt: DateTime.now()),
    );
    Navigator.of(tester.element(find.byType(NewRoutineScreen))).pop(true);
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
  });
}
