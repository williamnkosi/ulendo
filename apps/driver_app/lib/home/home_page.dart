import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/home/widgets/live_location_map.dart';
import 'package:driver_app/home/widgets/location_tracking_toggle.dart';
import 'package:driver_app/home/widgets/driver_offline_screen.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';
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
        child: BlocBuilder<PermissionsBloc, PermissionsState>(
          builder: (context, state) {
            if (state is PermissionsDriverGranted) {
              return BlocBuilder<RideManagementBloc, RideManagementState>(
                builder: (context, rideState) {
                  if (rideState is Offline) {
                    return const DriverOfflineScreen();
                  }
                  return const LiveLocationMap();
                },
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Driver Home'),
                  const SizedBox(height: 16),
                  if (state is PermissionsLoading)
                    const CircularProgressIndicator()
                  else
                    const Text('Checking permissions...'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
