import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              const Text('System settings will be managed here'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings not implemented')));
              }, child: const Text('Open Settings')),
            ],
          ),
        ),
      ),
    );
  }
}
