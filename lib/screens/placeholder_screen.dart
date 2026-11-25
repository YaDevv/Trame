import 'package:flutter/material.dart';

/// Ecran temporaire : montre la navigation avant que l'ecran reel existe.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Cet écran sera construit à une prochaine étape.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
