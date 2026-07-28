import 'package:flutter/material.dart';

import 'home_shell.dart';

void main() {
  runApp(const TallyApp());
}

class TallyApp extends StatelessWidget {
  const TallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}