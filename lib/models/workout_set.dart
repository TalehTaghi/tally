/// One logged set: reps × weight for an exercise within a workout.
///
/// [setNumber] is scoped per exercise within the workout — the 2nd set
/// of Bench Press and the 2nd set of Squat in the same session both
/// carry `setNumber: 2`. [WorkoutDao.saveWorkout] assigns the saved
/// number itself, so the value on an unsaved set is only a placeholder.
class WorkoutSet {
  final int? id;
  final int? workoutId;
  final int exerciseId;
  final int setNumber;
  final int reps;
  final double weight;

  const WorkoutSet({
    this.id,
    this.workoutId,
    required this.exerciseId,
    required this.setNumber,
    required this.reps,
    required this.weight,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'reps': reps,
      'weight': weight,
    };
  }

  factory WorkoutSet.fromMap(Map<String, Object?> map) {
    return WorkoutSet(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int?,
      exerciseId: map['exercise_id'] as int,
      setNumber: map['set_number'] as int,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
    );
  }
}
