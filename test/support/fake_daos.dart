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
  FakeRoutineDao(List<Routine> initial, {List<Exercise> exerciseCatalog = const []})
      : _routines = List.of(initial),
        _exerciseCatalog = List.of(exerciseCatalog);

  final List<Routine> _routines;
  final List<Exercise> _exerciseCatalog;
  final Map<int, List<int>> _exerciseIdsByRoutineId = {};
  Completer<void>? _blocker;

  String? lastCreatedName;
  List<int>? lastCreatedExerciseIds;

  void blockNextGetAll() => _blocker = Completer<void>();

  void releaseGetAll() => _blocker?.complete();

  /// Lets a test simulate another screen having created a routine,
  /// without going through [createRoutine].
  void addRoutine(Routine routine, {List<int> exerciseIds = const []}) {
    _routines.add(routine);
    _exerciseIdsByRoutineId[routine.id!] = List.of(exerciseIds);
  }

  @override
  Future<int> createRoutine(String name, List<int> exerciseIds) async {
    lastCreatedName = name;
    lastCreatedExerciseIds = exerciseIds;
    final id = _routines.length + 1;
    _routines.add(Routine(id: id, name: name, createdAt: DateTime.now()));
    _exerciseIdsByRoutineId[id] = List.of(exerciseIds);
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
    final ids = _exerciseIdsByRoutineId[routineId] ?? const [];
    return ids
        .map((id) => _exerciseCatalog.firstWhere((exercise) => exercise.id == id))
        .toList();
  }

  @override
  Future<void> addExerciseToRoutine(int routineId, int exerciseId) async {
    (_exerciseIdsByRoutineId[routineId] ??= []).add(exerciseId);
  }

  @override
  Future<void> removeExerciseFromRoutine(int routineId, int exerciseId) async {
    _exerciseIdsByRoutineId[routineId]?.remove(exerciseId);
  }

  @override
  Future<void> updateExerciseOrder(
    int routineId,
    List<int> orderedExerciseIds,
  ) async {
    _exerciseIdsByRoutineId[routineId] = List.of(orderedExerciseIds);
  }
}
