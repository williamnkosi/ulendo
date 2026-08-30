import 'package:flutter/material.dart';

/// A placeholder screen for the Activity feature/tab.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: Center(
        child: Text(
          'Activity Screen Placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
