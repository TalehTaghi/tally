/// A named plan (e.g. "Push Day") — the list of exercises it contains
/// lives in the separate `routine_exercises` join table, not here.
class Routine {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Routine({this.id, required this.name, required this.createdAt});

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Routine.fromMap(Map<String, Object?> map) {
    return Routine(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
    );
  }
}
