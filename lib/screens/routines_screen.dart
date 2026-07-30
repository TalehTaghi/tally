import 'package:flutter/material.dart';

import 'exercises_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

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
      body: const Center(
        child: Text('No routines yet'),
      ),
    );
  }
}
