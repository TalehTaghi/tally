import 'workout_set.dart';

/// What you did for one exercise in the most recent workout that
/// included it — a read model shaped for the log screen's hint, not a
/// table row.
class LastTime {
  final DateTime startedAt;

  /// That exercise's sets from that workout, in set-number order.
  final List<WorkoutSet> sets;

  const LastTime({required this.startedAt, required this.sets});
}
