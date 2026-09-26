import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/routine_dao.dart';
import '../data/workout_dao.dart';
import '../models/workout.dart';
import 'workout_detail_screen.dart';

/// A workout paired with the name of the routine it was logged from —
/// the one extra piece the list needs that the `workouts` row doesn't
/// carry.
typedef _HistoryEntry = ({Workout workout, String routineName});

class HistoryScreen extends StatefulWidget {
  HistoryScreen({super.key, WorkoutDao? workoutDao, RoutineDao? routineDao})
      : _workoutDao = workoutDao ?? WorkoutDao(),
        _routineDao = routineDao ?? RoutineDao();

  final WorkoutDao _workoutDao;
  final RoutineDao _routineDao;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<_HistoryEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  /// Loads workouts and routines side by side, then resolves each
  /// workout's routine name in memory. Two simple queries instead of a
  /// JOIN: the routines list is tiny, and it keeps [WorkoutDao] returning
  /// plain [Workout]s rather than a one-off joined shape.
  Future<List<_HistoryEntry>> _loadEntries() async {
    // A record of two Futures, awaited together — like
    // `await Promise.all([...])` in JS.
    final (workouts, routines) = await (
      widget._workoutDao.getAllWorkouts(),
      widget._routineDao.getAll(),
    ).wait;

    final routineNamesById = {
      for (final routine in routines) routine.id!: routine.name,
    };

    return [
      for (final workout in workouts)
        (
          workout: workout,
          routineName: routineNamesById[workout.routineId] ?? 'Unknown routine',
        ),
    ];
  }

  void _openWorkout(_HistoryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(
          workout: entry.workout,
          routineName: entry.routineName,
          workoutDao: widget._workoutDao,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<_HistoryEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load history.'));
          }

          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('No workouts logged yet.'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(entry.routineName),
                // e.g. "Wed, Aug 5, 2026"
                subtitle: Text(
                  DateFormat.yMMMEd().format(entry.workout.startedAt),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openWorkout(entry),
              );
            },
          );
        },
      ),
    );
  }
}
