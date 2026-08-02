import 'package:flutter/material.dart';

import '../data/routine_dao.dart';
import '../models/routine.dart';
import 'exercises_screen.dart';
import 'new_routine_screen.dart';
import 'routine_detail_screen.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatCreatedAt(DateTime dateTime) {
  return 'Created ${_monthNames[dateTime.month - 1]} ${dateTime.day}, '
      '${dateTime.year}';
}

class RoutinesScreen extends StatefulWidget {
  RoutinesScreen({super.key, RoutineDao? routineDao})
      : _routineDao = routineDao ?? RoutineDao();

  final RoutineDao _routineDao;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  late Future<List<Routine>> _routinesFuture;

  @override
  void initState() {
    super.initState();
    _routinesFuture = widget._routineDao.getAll();
  }

  void _refresh() {
    setState(() {
      _routinesFuture = widget._routineDao.getAll();
    });
  }

  Future<void> _openNewRoutineScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => NewRoutineScreen()),
    );
    if (created == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Exercises',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ExercisesScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Routine>>(
        future: _routinesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load routines.'));
          }

          final routines = snapshot.data!;
          if (routines.isEmpty) {
            return const Center(
              child: Text('No routines yet — tap + to create one.'),
            );
          }

          return ListView.builder(
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return ListTile(
                title: Text(routine.name),
                subtitle: Text(_formatCreatedAt(routine.createdAt)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          RoutineDetailScreen(routine: routine),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewRoutineScreen,
        tooltip: 'New routine',
        child: const Icon(Icons.add),
      ),
    );
  }
}
