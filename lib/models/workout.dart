import 'workout_set.dart';

/// One logged gym session, tied to a routine.
///
/// [sets] lives in memory only — it's the object graph assembled before
/// [WorkoutDao.saveWorkout] persists it. `toMap()`/`fromMap()` cover just
/// the `workouts` row; the set rows are a separate table, handled by the
/// DAO.
class Workout {
  final int? id;
  final int routineId;
  final DateTime startedAt;
  final List<WorkoutSet> sets;

  const Workout({
    this.id,
    required this.routineId,
    required this.startedAt,
    this.sets = const [],
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'started_at': startedAt.millisecondsSinceEpoch,
    };
  }

  factory Workout.fromMap(Map<String, Object?> map) {
    return Workout(
      id: map['id'] as int?,
      routineId: map['routine_id'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['started_at'] as int,
      ),
    );
  }
}
