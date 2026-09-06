import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/location/location_tracking_bloc.dart';

/// A reusable location tracking toggle button for the app bar
class LocationTrackingToggle extends StatelessWidget {
  const LocationTrackingToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationTrackingBloc, LocationTrackingState>(
      listener: (context, state) {
        if (state is LocationTrackingError) {
          print('LocationTrackingError: ${state.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: BlocBuilder<LocationTrackingBloc, LocationTrackingState>(
        builder: (context, state) {
          final isStreaming = state is LocationTrackingActive;
          final isLoading = state is LocationTrackingLoading;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: GestureDetector(
                onTap: isLoading
                    ? null
                    : () {
                        print(
                          'Toggle tapped. Current state: $state, isStreaming: $isStreaming',
                        );
                        if (isStreaming) {
                          print('Stopping location tracking');
                          context.read<LocationTrackingBloc>().add(
                            const StopLocationTracking(),
                          );
                        } else {
                          print('Starting location tracking');
                          context.read<LocationTrackingBloc>().add(
                            const StartLocationTracking(),
                          );
                        }
                      },
                child: Tooltip(
                  message: isLoading
                      ? 'Loading...'
                      : isStreaming
                          ? 'Stop tracking'
                          : 'Start tracking',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isLoading
                          ? Colors.orange.withOpacity(0.15)
                          : isStreaming
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isStreaming ? Colors.red : Colors.grey,
                                  ),
                                ),
                              )
                            : Icon(
                                isStreaming
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: isStreaming ? Colors.green : Colors.grey,
                                size: 18,
                              ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoading
                                  ? 'Loading...'
                                  : isStreaming
                                      ? 'Online'
                                      : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isLoading
                                    ? Colors.orange
                                    : isStreaming
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                            ),
                            if (isStreaming && state is LocationTrackingActive)
                              Text(
                                'Every ${state.updateInterval.inSeconds}s',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
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
