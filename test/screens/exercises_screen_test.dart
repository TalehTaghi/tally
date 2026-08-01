import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/data/exercise_dao.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/screens/exercises_screen.dart';

import '../support/fake_daos.dart';

void main() {
  Widget hostedScreen(ExerciseDao dao) {
    // NoSplash avoids triggering the Material ink-sparkle shader, which
    // this test environment's software renderer can't load.
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: ExercisesScreen(exerciseDao: dao),
    );
  }

  testWidgets('shows a spinner while loading', (tester) async {
    final dao = FakeExerciseDao([
      const Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest'),
    ])..blockNextGetAll();

    await tester.pumpWidget(hostedScreen(dao));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the seeded exercises once loaded', (tester) async {
    final dao = FakeExerciseDao([
      const Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest'),
      const Exercise(id: 2, name: 'Deadlift', muscleGroup: 'Back'),
    ]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
  });

  testWidgets('shows an empty-state message when there are no exercises', (
    tester,
  ) async {
    final dao = FakeExerciseDao([]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    expect(find.text('No exercises yet'), findsOneWidget);
  });

  testWidgets('adding an exercise inserts it and shows it without restarting', (
    tester,
  ) async {
    final dao = FakeExerciseDao([
      const Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest'),
    ]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Face Pull',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Face Pull'), findsOneWidget);
  });

  testWidgets('submitting an empty name is blocked with a hint', (
    tester,
  ) async {
    final dao = FakeExerciseDao([
      const Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest'),
    ]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    // The dialog stayed open instead of crashing or silently closing.
    expect(find.text('Add exercise'), findsOneWidget);
  });
}
