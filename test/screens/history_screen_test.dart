import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/models/routine.dart';
import 'package:tally/models/workout.dart';
import 'package:tally/models/workout_set.dart';
import 'package:tally/screens/history_screen.dart';
import 'package:tally/screens/workout_detail_screen.dart';

import '../support/fake_daos.dart';

const _benchPress = Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest');
const _pullUp = Exercise(id: 2, name: 'Pull Up', muscleGroup: 'Back');

void main() {
  final pushDay = Routine(id: 1, name: 'Push Day', createdAt: DateTime(2026));
  final pullDay = Routine(id: 2, name: 'Pull Day', createdAt: DateTime(2026));

  Widget hostedScreen(Widget screen) {
    // NoSplash avoids triggering the Material ink-sparkle shader, which
    // this test environment's software renderer can't load.
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: screen,
    );
  }

  group('HistoryScreen', () {
    testWidgets('shows an empty state when nothing has been logged', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostedScreen(
          HistoryScreen(
            workoutDao: FakeWorkoutDao(),
            routineDao: FakeRoutineDao([pushDay]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No workouts logged yet.'), findsOneWidget);
    });

    testWidgets('lists workouts newest first with routine name and date', (
      tester,
    ) async {
      final workoutDao = FakeWorkoutDao([
        Workout(id: 1, routineId: 1, startedAt: DateTime(2026, 8, 3, 18)),
        Workout(id: 2, routineId: 2, startedAt: DateTime(2026, 8, 5, 18)),
      ]);

      await tester.pumpWidget(
        hostedScreen(
          HistoryScreen(
            workoutDao: workoutDao,
            routineDao: FakeRoutineDao([pushDay, pullDay]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map(
            (tile) =>
                ((tile.title as Text).data, (tile.subtitle as Text).data),
          )
          .toList();
      expect(tiles, [
        ('Pull Day', 'Wed, Aug 5, 2026'),
        ('Push Day', 'Mon, Aug 3, 2026'),
      ]);
    });

    testWidgets('tapping a workout opens its detail view', (tester) async {
      final workoutDao = FakeWorkoutDao([
        Workout(id: 1, routineId: 1, startedAt: DateTime(2026, 8, 5, 18)),
      ]);

      await tester.pumpWidget(
        hostedScreen(
          HistoryScreen(
            workoutDao: workoutDao,
            routineDao: FakeRoutineDao([pushDay]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutDetailScreen), findsOneWidget);
    });
  });

  group('WorkoutDetailScreen', () {
    testWidgets('groups sets by exercise and shows weight × reps', (
      tester,
    ) async {
      final workout = Workout(
        id: 1,
        routineId: 1,
        startedAt: DateTime(2026, 8, 5, 18, 42),
        // Deliberately interleaved, the way a flat list of rows could
        // come back, to prove the screen groups them.
        sets: const [
          WorkoutSet(exerciseId: 2, setNumber: 1, reps: 10, weight: 0),
          WorkoutSet(exerciseId: 1, setNumber: 1, reps: 8, weight: 60),
          WorkoutSet(exerciseId: 1, setNumber: 2, reps: 6, weight: 62.5),
        ],
      );

      await tester.pumpWidget(
        hostedScreen(
          WorkoutDetailScreen(
            workout: workout,
            routineName: 'Push Day',
            workoutDao: FakeWorkoutDao([workout]),
            exerciseDao: FakeExerciseDao([_benchPress, _pullUp]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Push Day'), findsOneWidget);
      // intl puts a narrow no-break space (U+202F) before "PM", not a
      // plain space — \s matches either.
      expect(
        find.textContaining(RegExp(r'^Wed, Aug 5, 2026 6:42\sPM$')),
        findsOneWidget,
      );

      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));

      Iterable<String?> textsIn(Finder card) => tester
          .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
          .map((text) => text.data);

      expect(textsIn(cards.at(0)), [
        'Bench Press',
        '2 sets',
        'Set 1:  60 × 8',
        'Set 2:  62.5 × 6',
      ]);
      expect(textsIn(cards.at(1)), ['Pull Up', '1 set', 'Set 1:  0 × 10']);
    });
  });

  testWidgets('a workout saved through the DAO shows up on the next load', (
    tester,
  ) async {
    final workoutDao = FakeWorkoutDao();
    await workoutDao.saveWorkout(
      Workout(routineId: 1, startedAt: DateTime(2026, 8, 5, 18)),
    );

    await tester.pumpWidget(
      hostedScreen(
        HistoryScreen(
          workoutDao: workoutDao,
          routineDao: FakeRoutineDao([pushDay]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
  });
}
