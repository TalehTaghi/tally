/// A movement in the exercise catalog (e.g. "Bench Press").
///
/// [id] is null until the row has been inserted — sqflite assigns it via
/// AUTOINCREMENT, so we don't know it ahead of time.
class Exercise {
  final int? id;
  final String name;
  final String? muscleGroup;

  const Exercise({this.id, required this.name, this.muscleGroup});

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'muscle_group': muscleGroup,
    };
  }

  factory Exercise.fromMap(Map<String, Object?> map) {
    return Exercise(
      id: map['id'] as int?,
      name: map['name'] as String,
      muscleGroup: map['muscle_group'] as String?,
    );
  }
}
