import 'package:flutter/material.dart';

/// A placeholder screen for the Home feature/tab.
class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(
        child: Text('Driver Home'),
      ),
    );
  }
}
