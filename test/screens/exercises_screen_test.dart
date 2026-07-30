import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/data/exercise_dao.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/screens/exercises_screen.dart';

/// An in-memory stand-in for [ExerciseDao].
///
/// Real sqflite (even the "no isolate" ffi variant) does genuine file
/// I/O, which never reliably completes inside flutter_test's
/// FakeAsync-controlled pump loop — that's what backs `pump()`/
/// `pumpAndSettle()`. This fake keeps everything as plain in-memory
/// Dart Futures, which FakeAsync handles natively, so the screen's
/// FutureBuilder/dialog/refresh logic can be tested deterministically.
class _FakeExerciseDao extends ExerciseDao {
  _FakeExerciseDao(List<Exercise> initial) : _exercises = List.of(initial);

  final List<Exercise> _exercises;
  Completer<void>? _blocker;

  /// Makes the next [getAll] call wait until [releaseGetAll] is called,
  /// so a test can inspect the loading state deterministically.
  void blockNextGetAll() => _blocker = Completer<void>();

  void releaseGetAll() => _blocker?.complete();

  @override
  Future<List<Exercise>> getAll() async {
    if (_blocker != null) {
      await _blocker!.future;
    }
    final sorted = List.of(_exercises)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<int> insert(Exercise exercise) async {
    final id = _exercises.length + 1;
    _exercises.add(
      Exercise(id: id, name: exercise.name, muscleGroup: exercise.muscleGroup),
    );
    return id;
  }
}

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
    final dao = _FakeExerciseDao([
      const Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest'),
    ])..blockNextGetAll();

    await tester.pumpWidget(hostedScreen(dao));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the seeded exercises once loaded', (tester) async {
    final dao = _FakeExerciseDao([
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
    final dao = _FakeExerciseDao([]);

    await tester.pumpWidget(hostedScreen(dao));
    await tester.pumpAndSettle();

    expect(find.text('No exercises yet'), findsOneWidget);
  });

  testWidgets('adding an exercise inserts it and shows it without restarting', (
    tester,
  ) async {
    final dao = _FakeExerciseDao([
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
    final dao = _FakeExerciseDao([
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
