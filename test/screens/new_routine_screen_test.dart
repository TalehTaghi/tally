import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/screens/new_routine_screen.dart';

import '../support/fake_daos.dart';

void main() {
  late FakeExerciseDao exerciseDao;
  late FakeRoutineDao routineDao;
  bool? poppedResult;

  setUp(() {
    exerciseDao = FakeExerciseDao([
      const Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest'),
      const Exercise(id: 2, name: 'Deadlift', muscleGroup: 'Back'),
    ]);
    routineDao = FakeRoutineDao([]);
    poppedResult = null;
  });

  Widget hostedScreen() {
    // A Builder + push (rather than pumping NewRoutineScreen as `home`
    // directly) so the test can capture the value Navigator.pop sends
    // back, the same way RoutinesScreen does in the real app.
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => NewRoutineScreen(
                      exerciseDao: exerciseDao,
                      routineDao: routineDao,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows every exercise as a checkbox', (tester) async {
    await tester.pumpWidget(hostedScreen());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
  });

  testWidgets('saving with an empty name is blocked with a hint', (
    tester,
  ) async {
    await tester.pumpWidget(hostedScreen());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Bench Press'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(routineDao.lastCreatedName, isNull);
    // Still on the New Routine screen, not popped.
    expect(find.widgetWithText(AppBar, 'New Routine'), findsOneWidget);
  });

  testWidgets('saving with no exercise selected is blocked with a hint', (
    tester,
  ) async {
    await tester.pumpWidget(hostedScreen());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Routine name'),
      'Push Day',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one exercise'), findsOneWidget);
    expect(routineDao.lastCreatedName, isNull);
  });

  testWidgets(
    'saving with a name and selected exercises creates the routine and pops',
    (tester) async {
      await tester.pumpWidget(hostedScreen());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Routine name'),
        'Push Day',
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bench Press'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Deadlift'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(routineDao.lastCreatedName, 'Push Day');
      expect(routineDao.lastCreatedExerciseIds, [1, 2]);
      expect(poppedResult, true);
      // Back on the host screen, New Routine screen is gone.
      expect(find.text('open'), findsOneWidget);
    },
  );
}
