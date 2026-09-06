import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/location/location_tracking_toggle.dart';
import 'package:ulendo_core/permissions/permissions_bloc.dart';

/// A placeholder screen for the Home feature/tab.
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [LocationTrackingToggle()],
      ),
      body: BlocListener<PermissionsBloc, PermissionsState>(
        listener: (context, state) {
          if (state is PermissionsError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is PermissionsSuccess &&
              state.deniedPermissions.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Some permissions were denied: ${state.deniedPermissions.map((p) => p.name).join(", ")}',
                ),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    // TODO: Open app settings
                  },
                ),
              ),
            );
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Driver Home'),
              const SizedBox(height: 16),
              BlocBuilder<PermissionsBloc, PermissionsState>(
                builder: (context, state) {
                  if (state is PermissionsLoading) {
                    return const CircularProgressIndicator();
                  }
                  if (state is PermissionsDriverGranted) {
                    return const Text('Permissions Granted ✓');
                  }
                  return const Text('Checking permissions...');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
