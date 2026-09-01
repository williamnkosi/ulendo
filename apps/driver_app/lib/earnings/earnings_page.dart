import 'package:flutter/material.dart';

/// A placeholder screen for the Earnings feature/tab.
class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: const Center(
        child: Text('Driver Earnings'),
      ),
    );
  }
}
