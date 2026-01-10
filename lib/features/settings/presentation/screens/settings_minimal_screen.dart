import 'package:flutter/material.dart';

class SettingsMinimalScreen extends StatelessWidget {
  const SettingsMinimalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'As preferências de lembrete estão em Hábito.\nAs configurações avançadas ficam no menu lateral.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
