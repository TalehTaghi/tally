import 'package:flutter/material.dart';

import '../data/exercise_dao.dart';
import '../models/exercise.dart';

class ExercisesScreen extends StatefulWidget {
  ExercisesScreen({super.key, ExerciseDao? exerciseDao})
      : _dao = exerciseDao ?? ExerciseDao();

  final ExerciseDao _dao;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  late Future<List<Exercise>> _exercisesFuture;

  @override
  void initState() {
    super.initState();
    _exercisesFuture = widget._dao.getAll();
  }

  void _refresh() {
    setState(() {
      _exercisesFuture = widget._dao.getAll();
    });
  }

  Future<void> _openAddDialog() async {
    final newExercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => const _AddExerciseDialog(),
    );
    if (newExercise == null) {
      return;
    }
    await widget._dao.insert(newExercise);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: FutureBuilder<List<Exercise>>(
        future: _exercisesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load exercises.'));
          }

          final exercises = snapshot.data!;
          if (exercises.isEmpty) {
            return const Center(child: Text('No exercises yet'));
          }

          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return ListTile(
                title: Text(exercise.name),
                subtitle: exercise.muscleGroup != null
                    ? Text(exercise.muscleGroup!)
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        tooltip: 'Add exercise',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _muscleGroupController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _muscleGroupController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final muscleGroup = _muscleGroupController.text.trim();
    Navigator.pop(
      context,
      Exercise(
        name: _nameController.text.trim(),
        muscleGroup: muscleGroup.isEmpty ? null : muscleGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add exercise'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _muscleGroupController,
              decoration: const InputDecoration(
                labelText: 'Muscle group (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
