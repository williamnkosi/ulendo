import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/location/location_tracking_toggle.dart';
import 'package:ulendo_core/auth/auth_bloc.dart';
import 'package:ulendo_core/auth/auth_event.dart';

/// A placeholder screen for the Account feature/tab.
class DriverAccountPage extends StatelessWidget {
  const DriverAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: const [LocationTrackingToggle()],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            context.read<AuthBloc>().add(SignOutRequested());
          },
          child: const Text('Sign Out'),
        ),
      ),
    );
  }
}
