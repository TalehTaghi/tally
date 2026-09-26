import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/models/routine.dart';
import 'package:tally/models/workout.dart';
import 'package:tally/models/workout_set.dart';
import 'package:tally/screens/log_workout_screen.dart';
import 'package:tally/screens/routine_detail_screen.dart';

import '../support/fake_daos.dart';

const _benchPress = Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest');
const _pullUp = Exercise(id: 2, name: 'Pull Up', muscleGroup: 'Back');

void main() {
  final routine = Routine(id: 1, name: 'Push Day', createdAt: DateTime.now());

  late FakeRoutineDao routineDao;
  late FakeWorkoutDao workoutDao;

  setUp(() {
    routineDao = FakeRoutineDao([], exerciseCatalog: [_benchPress, _pullUp])
      ..addRoutine(routine, exerciseIds: [_benchPress.id!, _pullUp.id!]);
    workoutDao = FakeWorkoutDao();
  });

  /// Hosts the log screen on top of a placeholder home route, so popping
  /// it (on save or discard) has somewhere to go back to.
  Future<void> openLogScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // NoSplash avoids triggering the Material ink-sparkle shader, which
        // this test environment's software renderer can't load.
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LogWorkoutScreen(
                      routine: routine,
                      routineDao: routineDao,
                      workoutDao: workoutDao,
                    ),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
  }

  Finder repsField(int index) =>
      find.widgetWithText(TextField, 'Reps').at(index);
  Finder weightField(int index) =>
      find.widgetWithText(TextField, 'Weight').at(index);

  testWidgets('shows each exercise with one empty set row', (tester) async {
    await openLogScreen(tester);

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull Up'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Reps'), findsNWidgets(2));
  });

  testWidgets('Add set appends a row and Remove set deletes it', (
    tester,
  ) async {
    await openLogScreen(tester);

    await tester.tap(find.text('Add set').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Reps'), findsNWidgets(3));

    await tester.tap(find.byTooltip('Remove set').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Reps'), findsNWidgets(2));
  });

  testWidgets('removing a middle set keeps the other rows\' values', (
    tester,
  ) async {
    await openLogScreen(tester);
    await tester.tap(find.text('Add set').first);
    await tester.tap(find.text('Add set').first);
    await tester.pumpAndSettle();
    // Bench Press now has three rows: indexes 0, 1, 2.
    await tester.enterText(repsField(0), '10');
    await tester.enterText(repsField(1), '8');
    await tester.enterText(repsField(2), '6');

    await tester.tap(find.byTooltip('Remove set').at(1));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    expect(find.widgetWithText(TextField, '8'), findsNothing);
    expect(find.widgetWithText(TextField, '6'), findsOneWidget);
  });

  testWidgets('adding and removing many sets does not crash', (tester) async {
    // A tall test screen so all 22 rows fit without scrolling — taps on
    // off-screen buttons would silently miss.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openLogScreen(tester);

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('Add set').first);
      await tester.pump();
    }
    expect(find.widgetWithText(TextField, 'Reps'), findsNWidgets(22));
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byTooltip('Remove set').first);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Reps'), findsNWidgets(2));
  });

  testWidgets('saving builds one workout with numbered sets and pops', (
    tester,
  ) async {
    await openLogScreen(tester);
    await tester.tap(find.text('Add set').first);
    await tester.pumpAndSettle();
    // Bench Press: rows 0 and 1. Pull Up: row 2.
    await tester.enterText(repsField(0), '8');
    await tester.enterText(weightField(0), '60');
    await tester.enterText(repsField(1), '6');
    await tester.enterText(weightField(1), '62,5'); // comma decimal
    await tester.enterText(repsField(2), '10');
    await tester.enterText(weightField(2), '0'); // bodyweight

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workoutDao.savedWorkouts, hasLength(1));
    final workout = workoutDao.savedWorkouts.single;
    expect(workout.routineId, routine.id);
    expect(
      workout.sets.map((s) => (s.exerciseId, s.setNumber, s.reps, s.weight)),
      [
        (_benchPress.id!, 1, 8, 60.0),
        (_benchPress.id!, 2, 6, 62.5),
        (_pullUp.id!, 1, 10, 0.0),
      ],
    );
    expect(find.byType(LogWorkoutScreen), findsNothing);
  });

  testWidgets('saving with no sets is blocked', (tester) async {
    await openLogScreen(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workoutDao.savedWorkouts, isEmpty);
    expect(find.text('Log at least one set before saving.'), findsOneWidget);
    expect(find.byType(LogWorkoutScreen), findsOneWidget);
  });

  testWidgets('a half-filled set blocks saving and is highlighted', (
    tester,
  ) async {
    await openLogScreen(tester);
    await tester.enterText(repsField(0), '8'); // no weight
    await tester.enterText(repsField(1), '10');
    await tester.enterText(weightField(1), '0');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workoutDao.savedWorkouts, isEmpty);
    expect(find.text('Required'), findsOneWidget);

    await tester.enterText(weightField(0), '60');
    await tester.pump();
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('non-numeric input is filtered out of the fields', (
    tester,
  ) async {
    await openLogScreen(tester);

    await tester.enterText(repsField(0), 'abc');
    await tester.enterText(weightField(0), '6x0.5.5');
    await tester.pump();

    expect(find.widgetWithText(TextField, 'abc'), findsNothing);
    final weight = tester.widget<TextField>(weightField(0));
    expect(double.tryParse(weight.controller!.text), isNotNull);
  });

  testWidgets('backing out with entered sets asks before discarding', (
    tester,
  ) async {
    await openLogScreen(tester);
    await tester.enterText(repsField(0), '8');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard workout?'), findsOneWidget);

    await tester.tap(find.text('Keep logging'));
    await tester.pumpAndSettle();
    expect(find.byType(LogWorkoutScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(LogWorkoutScreen), findsNothing);
    expect(workoutDao.savedWorkouts, isEmpty);
  });

  testWidgets('backing out with nothing entered leaves without asking', (
    tester,
  ) async {
    await openLogScreen(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard workout?'), findsNothing);
    expect(find.byType(LogWorkoutScreen), findsNothing);
  });

  testWidgets('Start workout on a routine opens the log screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: RoutineDetailScreen(
          routine: routine,
          routineDao: routineDao,
          exerciseDao: FakeExerciseDao([_benchPress, _pullUp]),
          workoutDao: workoutDao,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Start workout'));
    await tester.pumpAndSettle();

    expect(find.byType(LogWorkoutScreen), findsOneWidget);
    expect(find.text('Add set'), findsNWidgets(2));
  });

  testWidgets('shows last time\'s sets per exercise, or No previous data', (
    tester,
  ) async {
    workoutDao = FakeWorkoutDao([
      Workout(
        id: 1,
        routineId: routine.id!,
        startedAt: DateTime(2026, 8, 1, 18),
        sets: [
          WorkoutSet(exerciseId: _benchPress.id!, setNumber: 1, reps: 8, weight: 60),
          WorkoutSet(exerciseId: _benchPress.id!, setNumber: 2, reps: 8, weight: 60),
          WorkoutSet(
            exerciseId: _benchPress.id!,
            setNumber: 3,
            reps: 6,
            weight: 62.5,
          ),
        ],
      ),
    ]);

    await openLogScreen(tester);

    expect(
      find.text('Last time (Aug 1): 60×8, 60×8, 62.5×6'),
      findsOneWidget,
    );
    // Pull Up has never been logged.
    expect(find.text('No previous data'), findsOneWidget);
  });

  testWidgets('the hint is read-only: set fields start empty', (
    tester,
  ) async {
    workoutDao = FakeWorkoutDao([
      Workout(
        id: 1,
        routineId: routine.id!,
        startedAt: DateTime(2026, 8, 1, 18),
        sets: [
          WorkoutSet(exerciseId: _benchPress.id!, setNumber: 1, reps: 8, weight: 60),
        ],
      ),
    ]);

    await openLogScreen(tester);

    final reps = tester.widget<TextField>(repsField(0));
    final weight = tester.widget<TextField>(weightField(0));
    expect(reps.controller!.text, isEmpty);
    expect(weight.controller!.text, isEmpty);
  });
}
