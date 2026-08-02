import 'package:flutter/material.dart';

import '../data/exercise_dao.dart';
import '../data/routine_dao.dart';
import '../models/exercise.dart';
import '../models/routine.dart';

class RoutineDetailScreen extends StatefulWidget {
  RoutineDetailScreen({
    super.key,
    required this.routine,
    RoutineDao? routineDao,
    ExerciseDao? exerciseDao,
  })  : _routineDao = routineDao ?? RoutineDao(),
        _exerciseDao = exerciseDao ?? ExerciseDao();

  final Routine routine;
  final RoutineDao _routineDao;
  final ExerciseDao _exerciseDao;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  List<Exercise>? _exercises;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await widget._routineDao.getExercisesForRoutine(
        widget.routine.id!,
      );
      if (!mounted) return;
      setState(() {
        _exercises = exercises;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    // The classic ReorderableListView gotcha: dragging an item downward
    // removes it from oldIndex first, which shifts every later index left
    // by one — so newIndex would land one slot too far unless corrected
    // (`if (newIndex > oldIndex) newIndex -= 1`). This Flutter version
    // fixes that in the framework itself via onReorderItem (below), which
    // reports newIndex already adjusted — the old onReorder callback,
    // which needed the manual fix, is deprecated as of this SDK.
    setState(() {
      final exercise = _exercises!.removeAt(oldIndex);
      _exercises!.insert(newIndex, exercise);
    });

    widget._routineDao.updateExerciseOrder(
      widget.routine.id!,
      _exercises!.map((exercise) => exercise.id!).toList(),
    );
  }

  Future<void> _removeExercise(Exercise exercise) async {
    await widget._routineDao.removeExerciseFromRoutine(
      widget.routine.id!,
      exercise.id!,
    );
    await _loadExercises();
  }

  Future<void> _openAddExercisePicker() async {
    final allExercises = await widget._exerciseDao.getAll();
    final existingIds = _exercises!.map((exercise) => exercise.id).toSet();
    final available = allExercises
        .where((exercise) => !existingIds.contains(exercise.id))
        .toList();

    if (!mounted) return;

    final selected = await showDialog<Exercise>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add exercise'),
        children: available.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('All exercises are already in this routine.'),
                ),
              ]
            : available
                .map(
                  (exercise) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, exercise),
                    child: Text(exercise.name),
                  ),
                )
                .toList(),
      ),
    );

    if (selected == null) {
      return;
    }

    await widget._routineDao.addExerciseToRoutine(
      widget.routine.id!,
      selected.id!,
    );
    await _loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.routine.name)),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _exercises == null ? null : _openAddExercisePicker,
        tooltip: 'Add exercise',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return const Center(child: Text('Could not load this routine.'));
    }

    final exercises = _exercises;
    if (exercises == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exercises.isEmpty) {
      return const Center(
        child: Text('No exercises yet — tap + to add one.'),
      );
    }

    return ReorderableListView.builder(
      itemCount: exercises.length,
      onReorderItem: _onReorder,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return ListTile(
          key: ValueKey(exercise.id),
          title: Text(exercise.name),
          subtitle: exercise.muscleGroup != null
              ? Text(exercise.muscleGroup!)
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: () => _removeExercise(exercise),
          ),
        );
      },
    );
  }
}
