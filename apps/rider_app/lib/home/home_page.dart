import 'package:flutter/material.dart';

/// A placeholder screen for the Home feature/tab.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Text(
          'Home Screen Placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
