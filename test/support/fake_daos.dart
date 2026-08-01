import 'dart:async';

import 'package:tally/data/exercise_dao.dart';
import 'package:tally/data/routine_dao.dart';
import 'package:tally/models/exercise.dart';
import 'package:tally/models/routine.dart';

/// In-memory stand-ins for the real DAOs.
///
/// Real sqflite (even the "no isolate" ffi variant) does genuine file
/// I/O, which never reliably completes inside flutter_test's
/// FakeAsync-controlled pump loop — that's what backs `pump()`/
/// `pumpAndSettle()`. These fakes keep everything as plain in-memory
/// Dart Futures, which FakeAsync handles natively, so screen tests can
/// exercise loading/error/refresh logic deterministically.
class FakeExerciseDao extends ExerciseDao {
  FakeExerciseDao(List<Exercise> initial) : _exercises = List.of(initial);

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

class FakeRoutineDao extends RoutineDao {
  FakeRoutineDao(List<Routine> initial) : _routines = List.of(initial);

  final List<Routine> _routines;
  Completer<void>? _blocker;

  String? lastCreatedName;
  List<int>? lastCreatedExerciseIds;

  void blockNextGetAll() => _blocker = Completer<void>();

  void releaseGetAll() => _blocker?.complete();

  /// Lets a test simulate another screen having created a routine,
  /// without going through [createRoutine].
  void addRoutine(Routine routine) => _routines.add(routine);

  @override
  Future<int> createRoutine(String name, List<int> exerciseIds) async {
    lastCreatedName = name;
    lastCreatedExerciseIds = exerciseIds;
    final id = _routines.length + 1;
    _routines.add(Routine(id: id, name: name, createdAt: DateTime.now()));
    return id;
  }

  @override
  Future<List<Routine>> getAll() async {
    if (_blocker != null) {
      await _blocker!.future;
    }
    final sorted = List.of(_routines)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<List<Exercise>> getExercisesForRoutine(int routineId) async {
    return [];
  }
}
