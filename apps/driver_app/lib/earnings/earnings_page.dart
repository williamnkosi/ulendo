import 'package:flutter/material.dart';
import 'package:driver_app/location/location_tracking_toggle.dart';

/// A placeholder screen for the Earnings feature/tab.
class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: const [LocationTrackingToggle()],
      ),
      body: const Center(child: Text('Driver Earnings')),
    );
  }
}
