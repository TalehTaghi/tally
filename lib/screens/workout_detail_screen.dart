import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/exercise_dao.dart';
import '../data/workout_dao.dart';
import '../models/workout.dart';
import '../models/workout_set.dart';

/// One exercise's sets within the workout, ready to render.
typedef _ExerciseGroup = ({String exerciseName, List<WorkoutSet> sets});

/// Shows weight without a pointless ".0" — 60.0 → "60", 62.5 → "62.5".
final _weightFormat = NumberFormat('0.##');

class WorkoutDetailScreen extends StatefulWidget {
  WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.routineName,
    WorkoutDao? workoutDao,
    ExerciseDao? exerciseDao,
  })  : _workoutDao = workoutDao ?? WorkoutDao(),
        _exerciseDao = exerciseDao ?? ExerciseDao();

  final Workout workout;
  final String routineName;
  final WorkoutDao _workoutDao;
  final ExerciseDao _exerciseDao;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Future<List<_ExerciseGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
  }

  /// Turns the flat list of set rows into one group per exercise.
  Future<List<_ExerciseGroup>> _loadGroups() async {
    final (sets, exercises) = await (
      widget._workoutDao.getSetsForWorkout(widget.workout.id!),
      widget._exerciseDao.getAll(),
    ).wait;

    final exerciseNamesById = {
      for (final exercise in exercises) exercise.id!: exercise.name,
    };

    // The in-memory GROUP BY exercise_id. A Dart map literal keeps keys in
    // insertion order, and getSetsForWorkout already returns sets ordered
    // by exercise then set number, so groups and the sets inside them
    // come out in that same order.
    final setsByExerciseId = <int, List<WorkoutSet>>{};
    for (final set in sets) {
      setsByExerciseId.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    return [
      for (final MapEntry(key: exerciseId, value: exerciseSets)
          in setsByExerciseId.entries)
        (
          exerciseName: exerciseNamesById[exerciseId] ?? 'Unknown exercise',
          sets: exerciseSets,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.routineName)),
      body: FutureBuilder<List<_ExerciseGroup>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this workout.'));
          }

          final groups = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                // e.g. "Wed, Aug 5, 2026 6:42 PM"
                child: Text(
                  DateFormat.yMMMEd().add_jm().format(widget.workout.startedAt),
                  style: textTheme.titleMedium,
                ),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sets were logged in this workout.'),
                ),
              for (final group in groups) _buildExerciseCard(group, textTheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExerciseCard(_ExerciseGroup group, TextTheme textTheme) {
    final setCount = group.sets.length;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.exerciseName, style: textTheme.titleMedium),
            Text(
              '$setCount ${setCount == 1 ? 'set' : 'sets'}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final set in group.sets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                // weight × reps, the usual lifting shorthand: "62.5 × 6".
                child: Text(
                  'Set ${set.setNumber}:  '
                  '${_weightFormat.format(set.weight)} × ${set.reps}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
