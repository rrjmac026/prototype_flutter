import 'package:flutter/material.dart';

class AuditLogsView extends StatelessWidget {
  const AuditLogsView({super.key});

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
              const Icon(Icons.description, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              const Text('Audit logs viewer will be here'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audit logs not implemented')));
              }, child: const Text('Open Audit Logs')),
            ],
          ),
        ),
      ),
    );
  }
}
