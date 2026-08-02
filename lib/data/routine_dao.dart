import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';
import '../models/routine.dart';
import 'database_helper.dart';

/// Owns all SQL for `routines` and the `routine_exercises` join table.
///
/// A [Routine] doesn't carry its exercises inline — they're loaded
/// separately via [getExercisesForRoutine], the same way you'd write two
/// queries in SQL rather than trying to cram a join's result into one
/// row-shaped object.
class RoutineDao {
  final DatabaseHelper _databaseHelper;

  RoutineDao({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Inserts the routine and its `routine_exercises` rows as one atomic
  /// transaction — a routine that ended up with only some of its
  /// exercises linked (because one insert failed partway through) would
  /// be corrupt data, so either all of it commits or none of it does.
  Future<int> createRoutine(String name, List<int> exerciseIds) async {
    final db = await _databaseHelper.database;

    return db.transaction((txn) async {
      final routineId = await txn.insert('routines', {
        'name': name,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      for (var position = 0; position < exerciseIds.length; position++) {
        await txn.insert('routine_exercises', {
          'routine_id': routineId,
          'exercise_id': exerciseIds[position],
          'position': position,
        });
      }

      return routineId;
    });
  }

  Future<List<Routine>> getAll() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('routines', orderBy: 'created_at DESC');
    return rows.map(Routine.fromMap).toList();
  }

  Future<List<Exercise>> getExercisesForRoutine(int routineId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT exercises.*
      FROM routine_exercises
      JOIN exercises ON exercises.id = routine_exercises.exercise_id
      WHERE routine_exercises.routine_id = ?
      ORDER BY routine_exercises.position
      ''',
      [routineId],
    );
    return rows.map(Exercise.fromMap).toList();
  }

  /// Links an exercise to a routine, placing it after everything already
  /// there. Only touches `routine_exercises` — the `exercises` catalog
  /// row is untouched, since the join table *is* the relationship.
  Future<void> addExerciseToRoutine(int routineId, int exerciseId) async {
    final db = await _databaseHelper.database;
    final nextPosition = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM routine_exercises WHERE routine_id = ?',
        [routineId],
      ),
    )!;

    await db.insert('routine_exercises', {
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'position': nextPosition,
    });
  }

  /// Unlinks an exercise from a routine. Deletes only the join row — the
  /// exercise itself still exists in the catalog for other routines.
  Future<void> removeExerciseFromRoutine(int routineId, int exerciseId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'routine_exercises',
      where: 'routine_id = ? AND exercise_id = ?',
      whereArgs: [routineId, exerciseId],
    );
  }

  /// Rewrites `position` for every exercise in [orderedExerciseIds] to
  /// match its index — the persisted form of a drag-to-reorder. One
  /// transaction so a reorder can't be left half-applied.
  Future<void> updateExerciseOrder(
    int routineId,
    List<int> orderedExerciseIds,
  ) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      for (var position = 0; position < orderedExerciseIds.length; position++) {
        await txn.update(
          'routine_exercises',
          {'position': position},
          where: 'routine_id = ? AND exercise_id = ?',
          whereArgs: [routineId, orderedExerciseIds[position]],
        );
      }
    });
  }
}
