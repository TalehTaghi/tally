import 'package:flutter/material.dart';

import '../data/exercise_dao.dart';
import '../data/routine_dao.dart';
import '../models/exercise.dart';

class NewRoutineScreen extends StatefulWidget {
  NewRoutineScreen({super.key, RoutineDao? routineDao, ExerciseDao? exerciseDao})
      : _routineDao = routineDao ?? RoutineDao(),
        _exerciseDao = exerciseDao ?? ExerciseDao();

  final RoutineDao _routineDao;
  final ExerciseDao _exerciseDao;

  @override
  State<NewRoutineScreen> createState() => _NewRoutineScreenState();
}

class _NewRoutineScreenState extends State<NewRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Set<int> _selectedExerciseIds = {};

  late final Future<List<Exercise>> _exercisesFuture;
  bool _showExerciseSelectionError = false;

  @override
  void initState() {
    super.initState();
    _exercisesFuture = widget._exerciseDao.getAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleExercise(int exerciseId, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _selectedExerciseIds.add(exerciseId);
      } else {
        _selectedExerciseIds.remove(exerciseId);
      }
    });
  }

  Future<void> _save() async {
    final isNameValid = _formKey.currentState!.validate();
    final hasExercises = _selectedExerciseIds.isNotEmpty;
    setState(() {
      _showExerciseSelectionError = !hasExercises;
    });
    if (!isNameValid || !hasExercises) {
      return;
    }

    await widget._routineDao.createRoutine(
      _nameController.text.trim(),
      _selectedExerciseIds.toList(),
    );

    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Routine'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Routine name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
            ),
            if (_showExerciseSelectionError)
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select at least one exercise',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<Exercise>>(
                future: _exercisesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load exercises.'),
                    );
                  }

                  final exercises = snapshot.data!;
                  if (exercises.isEmpty) {
                    return const Center(child: Text('No exercises yet'));
                  }

                  return ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      final exerciseId = exercise.id!;
                      return CheckboxListTile(
                        title: Text(exercise.name),
                        subtitle: exercise.muscleGroup != null
                            ? Text(exercise.muscleGroup!)
                            : null,
                        value: _selectedExerciseIds.contains(exerciseId),
                        onChanged: (selected) =>
                            _toggleExercise(exerciseId, selected),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
