import '../models/workout.dart';
import '../models/workout_set.dart';
import 'database_helper.dart';

/// Owns all SQL for `workouts` and `sets`.
class WorkoutDao {
  final DatabaseHelper _databaseHelper;

  WorkoutDao({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Saves the session and every one of its sets as one atomic
  /// transaction. [workout] is the fully assembled in-memory object
  /// graph — a workout that ended up with only some of its sets written
  /// (because one insert failed partway through) would be corrupt data,
  /// exactly like the routine/routine_exercises write in
  /// `RoutineDao.createRoutine`.
  ///
  /// `set_number` is assigned here, not taken from the caller: each
  /// exercise's sets are numbered 1, 2, 3… in the order they appear in
  /// [Workout.sets], so saved numbering never has gaps or duplicates.
  Future<int> saveWorkout(Workout workout) async {
    final db = await _databaseHelper.database;

    return db.transaction((txn) async {
      final workoutId = await txn.insert('workouts', {
        'routine_id': workout.routineId,
        'started_at': workout.startedAt.millisecondsSinceEpoch,
      });

      // exercise_id → how many of its sets we've inserted so far.
      final setCounts = <int, int>{};
      for (final set in workout.sets) {
        final setNumber = (setCounts[set.exerciseId] ?? 0) + 1;
        setCounts[set.exerciseId] = setNumber;

        await txn.insert('sets', {
          'workout_id': workoutId,
          'exercise_id': set.exerciseId,
          'set_number': setNumber,
          'reps': set.reps,
          'weight': set.weight,
        });
      }

      return workoutId;
    });
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('workouts', orderBy: 'started_at DESC');
    return rows.map(Workout.fromMap).toList();
  }

  Future<List<WorkoutSet>> getSetsForWorkout(int workoutId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'exercise_id, set_number',
    );
    return rows.map(WorkoutSet.fromMap).toList();
  }
}
