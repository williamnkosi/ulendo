import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';

/// Screen displayed when driver is waiting for passenger at pickup location
class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Logger logger = Logger(
      printer: PrefixPrinter(
        PrettyPrinter(methodCount: 0),
        info: '[WaitingScreen]',
        error: '[WaitingScreen]',
        warning: '[WaitingScreen]',
        debug: '[WaitingScreen]',
      ),
    );

    return BlocBuilder<RideManagementBloc, RideManagementState>(
      builder: (context, state) {
        if (state is! Waiting) {
          logger.w(
            'WaitingScreen received non-Waiting state: ${state.runtimeType}',
          );
          return Scaffold(
            body: Center(child: Text('Invalid state: ${state.runtimeType}')),
          );
        }

        logger.i('Building WaitingScreen for ride: ${state.rideId}');

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Button at top
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        logger.i(
                          'Passenger boarded - starting route to destination',
                        );
                        context.read<RideManagementBloc>().add(
                          const PassengerPickedUpEvent(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Passenger Boarded ✓',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Status section
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 80),
                        const SizedBox(height: 16),
                        const Text(
                          'You\'ve Arrived!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Passenger has been notified',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            state.rideRequest.pickup.address,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
