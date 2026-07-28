import 'package:flutter/material.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: const Center(
        child: Text('No routines yet'),
      ),
    );
  }
}
