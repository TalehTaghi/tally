import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/models/routine.dart';
import 'package:tally/screens/routine_detail_screen.dart';

import '../support/fake_daos.dart';

const _benchPress = Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest');
const _deadlift = Exercise(id: 2, name: 'Deadlift', muscleGroup: 'Back');
const _pullUp = Exercise(id: 3, name: 'Pull Up', muscleGroup: 'Back');

void main() {
  final routine = Routine(id: 1, name: 'Push Day', createdAt: DateTime.now());

  Widget hostedScreen({
    required FakeRoutineDao routineDao,
    required FakeExerciseDao exerciseDao,
  }) {
    // NoSplash avoids triggering the Material ink-sparkle shader, which
    // this test environment's software renderer can't load.
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: RoutineDetailScreen(
        routine: routine,
        routineDao: routineDao,
        exerciseDao: exerciseDao,
      ),
    );
  }

  testWidgets('shows the routine\'s exercises in position order', (
    tester,
  ) async {
    final routineDao =
        FakeRoutineDao([], exerciseCatalog: [_benchPress, _deadlift])
          ..addRoutine(
            routine,
            // Deliberately not alphabetical, to prove position order is
            // respected rather than the list being re-sorted by name.
            exerciseIds: [_deadlift.id!, _benchPress.id!],
          );
    final exerciseDao = FakeExerciseDao([_benchPress, _deadlift]);

    await tester.pumpWidget(
      hostedScreen(routineDao: routineDao, exerciseDao: exerciseDao),
    );
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(titles, ['Deadlift', 'Bench Press']);
  });

  testWidgets('shows an empty message when the routine has no exercises', (
    tester,
  ) async {
    final routineDao = FakeRoutineDao([])..addRoutine(routine);
    final exerciseDao = FakeExerciseDao([]);

    await tester.pumpWidget(
      hostedScreen(routineDao: routineDao, exerciseDao: exerciseDao),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No exercises yet'), findsOneWidget);
  });

  testWidgets('removing an exercise deletes only the join row', (
    tester,
  ) async {
    final routineDao =
        FakeRoutineDao([], exerciseCatalog: [_benchPress, _deadlift])
          ..addRoutine(routine, exerciseIds: [_benchPress.id!, _deadlift.id!]);
    final exerciseDao = FakeExerciseDao([_benchPress, _deadlift]);

    await tester.pumpWidget(
      hostedScreen(routineDao: routineDao, exerciseDao: exerciseDao),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Bench Press'),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('Deadlift'), findsOneWidget);
    // The catalog itself is untouched — only the join row was removed.
    final stillInCatalog = await exerciseDao.getAll();
    expect(stillInCatalog.map((e) => e.name), contains('Bench Press'));
  });

  testWidgets('the add-exercise picker excludes exercises already present', (
    tester,
  ) async {
    final routineDao =
        FakeRoutineDao([], exerciseCatalog: [_benchPress, _deadlift, _pullUp])
          ..addRoutine(routine, exerciseIds: [_benchPress.id!]);
    final exerciseDao = FakeExerciseDao([_benchPress, _deadlift, _pullUp]);

    await tester.pumpWidget(
      hostedScreen(routineDao: routineDao, exerciseDao: exerciseDao),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final dialog = find.byType(SimpleDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Bench Press')),
      findsNothing, // already in the routine
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Deadlift')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Pull Up')),
      findsOneWidget,
    );
  });

  testWidgets('picking an exercise adds it to the routine and refreshes', (
    tester,
  ) async {
    final routineDao =
        FakeRoutineDao([], exerciseCatalog: [_benchPress, _deadlift])
          ..addRoutine(routine, exerciseIds: [_benchPress.id!]);
    final exerciseDao = FakeExerciseDao([_benchPress, _deadlift]);

    await tester.pumpWidget(
      hostedScreen(routineDao: routineDao, exerciseDao: exerciseDao),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deadlift'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
  });

  testWidgets('reordering updates the list and persists the new order', (
    tester,
  ) async {
    final routineDao =
        FakeRoutineDao([], exerciseCatalog: [_benchPress, _deadlift, _pullUp])
          ..addRoutine(
            routine,
            exerciseIds: [_benchPress.id!, _deadlift.id!, _pullUp.id!],
          );
    final exerciseDao = FakeExerciseDao([_benchPress, _deadlift, _pullUp]);

    await tester.pumpWidget(
      hostedScreen(routineDao: routineDao, exerciseDao: exerciseDao),
    );
    await tester.pumpAndSettle();

    // Drive the reorder callback directly rather than simulating a drag
    // gesture — this exercises the exact same index-handling logic the
    // real drag interaction triggers, without relying on fragile
    // pointer-offset choreography in a test environment.
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 2); // move Bench Press to the end
    await tester.pumpAndSettle();

    final titlesAfterReorder = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(titlesAfterReorder, ['Deadlift', 'Pull Up', 'Bench Press']);

    final persisted = await routineDao.getExercisesForRoutine(routine.id!);
    expect(persisted.map((e) => e.name), ['Deadlift', 'Pull Up', 'Bench Press']);
  });
}
