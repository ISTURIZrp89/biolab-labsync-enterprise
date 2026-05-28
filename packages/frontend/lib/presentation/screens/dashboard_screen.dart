import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BioLab LABSYNC'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Dashboard - BioLab LABSYNC Enterprise',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
