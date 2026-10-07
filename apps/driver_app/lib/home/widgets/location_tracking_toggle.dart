import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';

/// A reusable location tracking toggle button for the app bar
class LocationTrackingToggle extends StatelessWidget {
  const LocationTrackingToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideManagementBloc, RideManagementState>(
      listener: (context, state) {
        if (state is RideManagementError) {
          print('RideManagementError: ${state.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: BlocBuilder<RideManagementBloc, RideManagementState>(
        builder: (context, state) {
          final isOnline = state is! Offline;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (isOnline) {
                    context.read<RideManagementBloc>().add(
                      const GoOfflineEvent(),
                    );
                  } else {
                    context.read<RideManagementBloc>().add(
                      const GoOnlineEvent(),
                    );
                  }
                },
                child: Tooltip(
                  message: isOnline ? 'Go offline' : 'Go online',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isOnline
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline ? Icons.location_on : Icons.location_off,
                          color: isOnline ? Colors.green : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
